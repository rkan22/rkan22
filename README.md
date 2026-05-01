# Flask API Deploy Hazırlığı

Bu proje GitHub, Render ve Vercel deployment için hazırlanmıştır.

## Lokal Çalıştırma

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python app.py
```

API test:

```bash
curl "http://127.0.0.1:5000/get_full_iccid_details?iccid=1234567890123456789"
```

## GitHub'a Push

```bash
git init
git add .
git commit -m "Prepare Flask API for GitHub, Render, and Vercel deploy"
git remote add origin <REPO_URL>
git push -u origin <BRANCH>
```

## Render Deploy

1. Render hesabında **New + > Web Service** seçin.
2. GitHub repository bağlayın.
3. Render otomatik `render.yaml` dosyasını okuyacaktır.
4. Environment Variables bölümüne aşağıdaki değişkenleri ekleyin.

## Vercel Deploy

1. Vercel hesabında **Add New Project** ile repo import edin.
2. `vercel.json` ve `api/index.py` üzerinden serverless Flask deploy edilir.
3. Project Settings > Environment Variables altında aşağıdaki değişkenleri tanımlayın.

## Environment Variables

Aşağıdaki değişkenler zorunludur:

- `ACCOUNT_ID`
- `SIGN_KEY`
- `SECRET_KEY`
- `VECTOR`
- `API_VERSION`
- `BASE_URL`

Örnek `.env.example`:

```env
ACCOUNT_ID=your_account_id
SIGN_KEY=your_sign_key
SECRET_KEY=your_secret_key
VECTOR=your_vector
API_VERSION=v1
BASE_URL=https://api.example.com
```

## curl Test Örneği

```bash
curl "https://<host>/get_full_iccid_details?iccid=1234567890123456789"
```

## Güvenlik Notu

- Kodda daha önce secret/token bulunduysa mutlaka rotate (yenileme) yapılmalıdır.
- `.env` dosyası asla GitHub'a commit edilmemelidir.
