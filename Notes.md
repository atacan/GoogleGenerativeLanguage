## Uploading files

First create a upload session:

```HTTP
POST /upload/v1beta/files HTTP/1.1
Host: generativelanguage.googleapis.com
Accept: */*
Accept-Encoding: gzip, deflate
Connection: keep-alive
Content-Type: application/json
x-goog-api-key: ******
user-agent: google-genai-sdk/1.21.1 gl-python/3.13.5
x-goog-api-client: google-genai-sdk/1.21.1 gl-python/3.13.5
X-Goog-Upload-Protocol: resumable
X-Goog-Upload-Command: start
X-Goog-Upload-Header-Content-Length: 889389
X-Goog-Upload-Header-Content-Type: audio/mpeg
Content-Length: 57

{"file": {"mimeType": "audio/mpeg", "sizeBytes": 889389}}
```

This will return a response like the following with empty body:

```HTTP
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
X-GUploader-UploadID: ABgVH8-nlN8xjYU-2m28TEvS1vW1NOIFKk0Xe3qeNB9jjeCtVF6h5xJJ_EBQzUQk8Jwwvu6uA-UroEQ073YiiRpmhuPCUCN_P2oDFxfCC_4toA
X-Goog-Upload-Status: active
X-Goog-Upload-URL: https://generativelanguage.googleapis.com/upload/v1beta/files?upload_id=ABgVH8-nlN8xjYU-2m28TEvS1vW1NOIFKk0Xe3qeNB9jjeCtVF6h5xJJ_EBQzUQk8Jwwvu6uA-UroEQ073YiiRpmhuPCUCN_P2oDFxfCC_4toA&upload_protocol=resumable
X-Goog-Upload-Control-URL: https://generativelanguage.googleapis.com/upload/v1beta/files?upload_id=ABgVH8-nlN8xjYU-2m28TEvS1vW1NOIFKk0Xe3qeNB9jjeCtVF6h5xJJ_EBQzUQk8Jwwvu6uA-UroEQ073YiiRpmhuPCUCN_P2oDFxfCC_4toA&upload_protocol=resumable
X-Goog-Upload-Chunk-Granularity: 8388608
X-Goog-Upload-Header-x-google-esf-cloud-client-params: backend_service_name: "generativelanguage.googleapis.com" backend_fully_qualified_method: "google.ai.generativelanguage.v1beta.FileService.CreateFile"
X-Goog-Upload-Header-X-Google-Session-Info: GgQYECgLIAE6IxIhZ2VuZXJhdGl2ZWxhbmd1YWdlLmdvb2dsZWFwaXMuY29t
X-Goog-Upload-Header-X-Google-Backends: unix:/tmp/esfbackend.1750757119.810213.1592910
X-Goog-Upload-Header-Content-Type: application/json; charset=UTF-8
X-Goog-Upload-Header-X-Google-Security-Signals: FRAMEWORK=ONE_PLATFORM,ENV=borg,ENV_DEBUG=borg_user:genai-api;borg_job:prod.genai-api
X-Goog-Upload-Header-Vary: Origin
X-Goog-Upload-Header-Vary: X-Origin
X-Goog-Upload-Header-Vary: Referer
X-Goog-Upload-Header-X-Google-GFE-Backend-Request-Cost: 11.3243
Content-Length: 0
Date: Tue, 24 Jun 2025 12:57:40 GMT
Server: UploadServer
Alt-Svc: h3=":443"; ma=2592000,h3-29=":443"; ma=2592000
```

Then upload the file using the upload_id from the previous response header X-GUploader-UploadID:

```HTTP
POST /upload/v1beta/files?upload_id=ABgVH8-nlN8xjYU-2m28TEvS1vW1NOIFKk0Xe3qeNB9jjeCtVF6h5xJJ_EBQzUQk8Jwwvu6uA-UroEQ073YiiRpmhuPCUCN_P2oDFxfCC_4toA&upload_protocol=resumable HTTP/1.1
Host: generativelanguage.googleapis.com
Accept: */*
Accept-Encoding: gzip, deflate
Connection: keep-alive
User-Agent: python-httpx/0.28.1
X-Goog-Upload-Command: upload, finalize
X-Goog-Upload-Offset: 0
Content-Length: 889389

<Binary Data>
```

This will return a response like the following:

```HTTP
HTTP/1.1 200 OK
Content-Type: application/json; charset=UTF-8
X-GUploader-UploadID: ABgVH8-nlN8xjYU-2m28TEvS1vW1NOIFKk0Xe3qeNB9jjeCtVF6h5xJJ_EBQzUQk8Jwwvu6uA-UroEQ073YiiRpmhuPCUCN_P2oDFxfCC_4toA
X-Goog-Upload-Status: final
Vary: Origin
Vary: X-Origin
Vary: Referer
Content-Length: 505
Date: Tue, 24 Jun 2025 12:57:41 GMT
Server: UploadServer
Alt-Svc: h3=":443"; ma=2592000,h3-29=":443"; ma=2592000

{
  "file": {
    "name": "files/azucr4abxgje",
    "mimeType": "audio/mpeg",
    "sizeBytes": "889389",
    "createTime": "2025-06-24T12:57:41.657029Z",
    "updateTime": "2025-06-24T12:57:41.657029Z",
    "expirationTime": "2025-06-26T12:57:41.592657449Z",
    "sha256Hash": "ZTIzNTQyNDFlNDQ4YjkxYWZlNGY4NjhkNzNhOWVmMGMyNmIzMjdlZWMzMGEyMjkwMTY1Y2U5ZTQ2MTc5ZTAzNw==",
    "uri": "https://generativelanguage.googleapis.com/v1beta/files/azucr4abxgje",
    "state": "ACTIVE",
    "source": "UPLOADED"
  }
}
```