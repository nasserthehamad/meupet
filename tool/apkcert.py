import struct, sys, hashlib
def certs(path):
    d=open(path,'rb').read()
    eocd=d.rfind(b'PK\x05\x06')
    cd_off=struct.unpack('<I', d[eocd+16:eocd+20])[0]
    assert d[cd_off-16:cd_off]==b'APK Sig Block 42', 'sem bloco de assinatura'
    size=struct.unpack('<Q', d[cd_off-24:cd_off-16])[0]
    start=cd_off-size-8
    pairs=d[start+8:cd_off-24]; i=0; out={}
    while i<len(pairs):
        ln=struct.unpack('<Q',pairs[i:i+8])[0]; pid=struct.unpack('<I',pairs[i+8:i+12])[0]; val=pairs[i+12:i+8+ln]; i+=8+ln
        if pid in (0x7109871a,0xf05368c0):
            def lp(b,o): n=struct.unpack('<I',b[o:o+4])[0]; return b[o+4:o+4+n], o+4+n
            signers,_=lp(val,0); signer,_=lp(signers,0); signed,_=lp(signer,0)
            digests,o=lp(signed,0); certseq,o=lp(signed,o); cert,_=lp(certseq,0)
            out['v2' if pid==0x7109871a else 'v3']=hashlib.sha256(cert).hexdigest().upper()
    return out
for p in sys.argv[1:]: print(p.split('/')[-1], certs(p))
