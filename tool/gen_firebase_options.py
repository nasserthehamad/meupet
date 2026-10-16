#!/usr/bin/env python3
"""Gera lib/firebase_options.dart a partir de android-config/google-services.json.

Roda no GitHub Actions antes do build (e localmente, se quiser).
Uso: python3 tool/gen_firebase_options.py [caminho/google-services.json]
"""
import json
import pathlib
import sys

PACKAGE = "com.meupet.app"
root = pathlib.Path(__file__).resolve().parent.parent
src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / "android-config" / "google-services.json"
if not src.exists():
    # Sem configuração: gera valores provisórios só para o código compilar.
    print(f"AVISO: {src} não encontrado — gerando configuração PROVISÓRIA (o app não vai conectar).")
    cfg = {
        "project_info": {"project_number": "0", "project_id": "placeholder", "storage_bucket": ""},
        "client": [{
            "client_info": {"mobilesdk_app_id": "1:0:android:0", "android_client_info": {"package_name": PACKAGE}},
            "api_key": [{"current_key": "placeholder"}],
        }],
    }
else:
    cfg = json.loads(src.read_text(encoding="utf-8"))
info = cfg["project_info"]
client = next(
    (c for c in cfg["client"] if c["client_info"]["android_client_info"]["package_name"] == PACKAGE),
    cfg["client"][0],
)

values = {
    "apiKey": client["api_key"][0]["current_key"],
    "appId": client["client_info"]["mobilesdk_app_id"],
    "messagingSenderId": info["project_number"],
    "projectId": info["project_id"],
    "storageBucket": info.get("storage_bucket", ""),
}

body = "\n".join(f"    {k}: '{v}'," for k, v in values.items())
out = f"""// GERADO AUTOMATICAMENTE por tool/gen_firebase_options.py — não edite.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
{body}
  );
}}
"""
(root / "lib" / "firebase_options.dart").write_text(out, encoding="utf-8")
print("lib/firebase_options.dart gerado para o projeto", values["projectId"])
