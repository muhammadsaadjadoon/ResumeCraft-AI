import json
import httpx
import pytest
from fastapi.testclient import TestClient
import app as module

@pytest.fixture(autouse=True)
def setup(monkeypatch):
    monkeypatch.setenv('DEV_NO_AUTH','true')
    monkeypatch.setenv('APP_ENV','development')
    module.requests_by_user.clear()

@pytest.fixture
def client():
    return TestClient(module.app)

def output():
    return module.AiOutput(resume=module.ResumeContent(name='Invented name', summary='Refined summary'),suggestions=['Add verified outcomes.'])

def test_auth_required(client,monkeypatch):
    monkeypatch.setenv('DEV_NO_AUTH','false')
    assert client.post('/v1/assist',json={'resume':{'name':'Saadi'}}).status_code==401

def test_dev_bypass_prohibited_in_production(client,monkeypatch):
    monkeypatch.setenv('APP_ENV','production')
    assert client.post('/v1/assist',json={'resume':{'name':'Saadi'}}).status_code==503

def test_rewrite_preserves_contact_facts(client,monkeypatch):
    async def fake(_): return output()
    monkeypatch.setattr(module,'generate',fake)
    response=client.post('/v1/assist',json={'resume':{'name':'Saadi','email':'saadi@example.com'},'mode':'rewrite'})
    assert response.status_code==200
    assert response.json()['resume']['name']=='Saadi'
    assert response.json()['resume']['email']=='saadi@example.com'
    assert response.json()['resume']['summary']=='Refined summary'

def test_review_never_rewrites(client,monkeypatch):
    async def fake(_): return output()
    monkeypatch.setattr(module,'generate',fake)
    response=client.post('/v1/assist',json={'resume':{'name':'Saadi','summary':'Original'},'mode':'review','job':'Flutter developer'})
    assert response.json()['resume']['summary']=='Original'

def test_empty_background_rejected(client):
    assert client.post('/v1/assist',json={'resume':{}}).status_code==422

def test_job_required_for_review(client):
    assert client.post('/v1/assist',json={'resume':{'name':'Saadi'},'mode':'review'}).status_code==422

def test_input_size_validation(client):
    assert client.post('/v1/import',json={'text':'x'*20001}).status_code==422

def test_fake_pdf_rejected(client):
    response=client.post('/v1/import-pdf',files={'file':('profile.pdf',b'fake pdf','application/pdf')})
    assert response.status_code==422

def test_missing_key_has_actionable_error(client,monkeypatch):
    monkeypatch.delenv('GEMINI_API_KEY',raising=False)
    response=client.post('/v1/assist',json={'resume':{'name':'Saadi'}})
    assert response.status_code==503
    assert 'configured' in response.json()['detail']

def test_rate_limit(client):
    for _ in range(8):
        client.post('/v1/import',json={'text':'short'})
    assert client.post('/v1/import',json={'text':'short'}).status_code==429

def test_request_body_limit(client):
    assert client.post('/v1/import',content=b'x'*5_100_001).status_code==413

def test_health(client):
    response=client.get('/health')
    assert response.status_code==200
    assert response.headers['cache-control']=='no-store'

@pytest.mark.parametrize('status,expected',[(403,503),(429,429),(404,503),(500,502)])
def test_upstream_errors_are_sanitized(client,monkeypatch,status,expected):
    monkeypatch.setenv('GEMINI_API_KEY','test-secret')
    class FakeClient:
        def __init__(self,**kwargs):pass
        async def __aenter__(self):return self
        async def __aexit__(self,*args):pass
        async def post(self,*args,**kwargs):return httpx.Response(status,json={'error':'test-secret'})
    monkeypatch.setattr(module.httpx,'AsyncClient',FakeClient)
    response=client.post('/v1/assist',json={'resume':{'name':'Saadi'}})
    assert response.status_code==expected
    assert 'test-secret' not in response.text

def test_bad_upstream_json_rejected(client,monkeypatch):
    monkeypatch.setenv('GEMINI_API_KEY','test-secret')
    class FakeClient:
        def __init__(self,**kwargs):pass
        async def __aenter__(self):return self
        async def __aexit__(self,*args):pass
        async def post(self,*args,**kwargs):return httpx.Response(200,json={'candidates':[{'content':{'parts':[{'text':'{}'}]}}]})
    monkeypatch.setattr(module.httpx,'AsyncClient',FakeClient)
    assert client.post('/v1/assist',json={'resume':{'name':'Saadi'}}).status_code==502

def test_missing_server_project_is_not_a_session_error(client,monkeypatch):
    monkeypatch.setenv('DEV_NO_AUTH','false')
    monkeypatch.delenv('FIREBASE_PROJECT_ID',raising=False)
    response=client.post('/v1/assist',headers={'Authorization':'Bearer example'},json={'resume':{'name':'Saadi'}})
    assert response.status_code==503
    assert 'FIREBASE_PROJECT_ID' in response.json()['detail']

def test_valid_verified_session(client,monkeypatch):
    monkeypatch.setenv('DEV_NO_AUTH','false')
    monkeypatch.setenv('FIREBASE_PROJECT_ID','unit-project')
    monkeypatch.setattr(module,'verify_session',lambda raw,project:{'sub':'unit-user'})
    async def fake(_):return output()
    monkeypatch.setattr(module,'generate',fake)
    assert client.post('/v1/assist',headers={'Authorization':'Bearer valid'},json={'resume':{'name':'Saadi'}}).status_code==200

def test_invalid_session_rejected(client,monkeypatch):
    monkeypatch.setenv('DEV_NO_AUTH','false')
    monkeypatch.setenv('FIREBASE_PROJECT_ID','unit-project')
    def bad(*args):raise ValueError('invalid')
    monkeypatch.setattr(module,'verify_session',bad)
    assert client.post('/v1/assist',headers={'Authorization':'Bearer bad'},json={'resume':{'name':'Saadi'}}).status_code==401

def test_certificate_network_error_is_retryable(client,monkeypatch):
    monkeypatch.setenv('DEV_NO_AUTH','false')
    monkeypatch.setenv('FIREBASE_PROJECT_ID','unit-project')
    def bad(*args):raise module.google_errors.TransportError('unavailable')
    monkeypatch.setattr(module,'verify_session',bad)
    assert client.post('/v1/assist',headers={'Authorization':'Bearer bad'},json={'resume':{'name':'Saadi'}}).status_code==503

def test_create_resume_from_facts_preserves_identity(client,monkeypatch):
    async def fake(payload):
        data=json.loads(payload)
        assert 'Flutter internship' in data['provided_facts']
        return output()
    monkeypatch.setattr(module,'generate',fake)
    response=client.post('/v1/create',json={'resume':{'name':'Saadi','email':'saadi@example.com','role':'Flutter Developer'},'facts':'Software student with Flutter internship and API projects.'})
    assert response.status_code==200
    assert response.json()['resume']['name']=='Saadi'
    assert response.json()['resume']['role']=='Flutter Developer'

def test_create_requires_background(client):
    assert client.post('/v1/create',json={'resume':{'name':'Saadi'},'facts':'short'}).status_code==422

@pytest.fixture
def signed_token(monkeypatch):
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives import serialization,hashes
    from cryptography import x509
    from cryptography.x509.oid import NameOID
    from google.auth import jwt,crypt
    from datetime import datetime,timezone,timedelta
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    private=key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())
    name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'unit-test')])
    now=datetime.now(timezone.utc)
    cert=x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(1).not_valid_before(now-timedelta(days=1)).not_valid_after(now+timedelta(days=1)).sign(key,hashes.SHA256())
    cert_pem=cert.public_bytes(serialization.Encoding.PEM).decode()
    class Response:
        status=200
        data=json.dumps({'unit-key':cert_pem}).encode()
    monkeypatch.setattr(module,'GoogleRequest',lambda:lambda *a,**kw:Response())
    monkeypatch.setenv('CHECK_REVOKED','false')
    signer=crypt.RSASigner.from_string(private,key_id='unit-key')
    def make(**changes):
        import time
        epoch=int(time.time())
        claims={'iss':'https://securetoken.google.com/unit-project','aud':'unit-project','sub':'unit-user','iat':epoch,'exp':epoch+3600,'auth_time':epoch}
        claims.update(changes)
        return jwt.encode(signer,claims).decode()
    return make

def test_real_signed_token_verification(signed_token):
    assert module.verify_session(signed_token(),'unit-project')['sub']=='unit-user'

@pytest.mark.parametrize('changes',[{'aud':'other-project'},{'iss':'https://evil.example'},{'exp':1},{'sub':''},{'auth_time':9999999999}])
def test_signed_invalid_claims_rejected(signed_token,changes):
    with pytest.raises(ValueError):module.verify_session(signed_token(**changes),'unit-project')

def test_tampered_signature_rejected(signed_token):
    token=signed_token()
    parts=token.split('.')
    parts[2]=('A' if parts[2][0]!='A' else 'B')+parts[2][1:]
    with pytest.raises(ValueError):module.verify_session('.'.join(parts),'unit-project')
