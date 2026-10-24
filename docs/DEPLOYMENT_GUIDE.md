# دليل نشر واستضافة منصة مرساة (Deployment Guide)

يوضح هذا الدليل كيفية نشر مكونات منصة مرساة سحابياً:
1. **الموقع التعريفي وحجز المواعيد** على **Vercel**
2. **تطبيق العيادة الطبي (Flutter Web)** على **Vercel**
3. **الخادم الخلفي وقاعدة البيانات (FastAPI)** على **Render** أو **Railway**

---

## 1. نشر الموقع التعريفي على Vercel (`web/public`)

الموقع مبني بـ HTML/CSS/JavaScript خالص، واستضافته سريعة ومجانية تماماً:

1. ارفع المشروع إلى حسابك على GitHub.
2. توجه إلى لوحة تحكم [Vercel](https://vercel.com/) واضغط على **Add New...** ثم **Project**.
3. قم باستيراد مستودع المشروع `Marsa`.
4. اضبط الإعدادات التالية:
   - **Project Name**: `marsa-clinic`
   - **Framework Preset**: `Other`
   - **Root Directory**: اضغط `Edit` واختر `web/public`
5. اضغط **Deploy**.
6. بعد اكتمال النشر، ستحصل على رابط مباشر مثل: `https://marsa-clinic.vercel.app`.

---

## 2. نشر تطبيق العيادة الإكلينيكي (Flutter Web) على Vercel (`app`)

تم تجهيز ملف `app/vercel.json` وسكربت `app/build.sh` مسبقاً داخل مجلد `app`.

1. في لوحة تحكم Vercel، اضغط **Add New...** ثم **Project** واختر نفس المستودع مرة أخرى.
2. اضبط الإعدادات:
   - **Project Name**: `marsa-portal`
   - **Framework Preset**: `Other`
   - **Root Directory**: اختر `app`
   - **Build and Output Settings**:
     - **Output Directory**: `build/web`
3. في قسم **Environment Variables** (المتغيرات البيئية):
   - أضف المتغير: `API_BASE_URL`
   - القيمة: رابط الباك إند الخاص بك (مثلاً: `https://marsa-api.onrender.com`)
4. اضغط **Deploy**.
5. سيقوم Vercel بتشغيل `build.sh` وتحميل فلاتر وبناء التطبيق كـ Single Page Application (SPA).

---

## 3. نشر الخادم الخلفي (FastAPI) على Render (مجاناً)

نظرًا لأن الباك إند يعتمد على Python وقاعدة بيانات وتشفير AES-256، فإن أفضل منصة مجانية/سريعة له هي [Render.com](https://render.com/):

1. أنشئ حساباً مجانياً على [Render](https://render.com/).
2. اضغط على **New +** ثم اختر **Web Service**.
3. اربط مستودع GitHub الخاص بـ `Marsa`.
4. اضبط إعدادات الخدمة:
   - **Name**: `marsa-backend`
   - **Region**: Frankfurt (أقرب منطقة لمصر)
   - **Root Directory**: `backend`
   - **Runtime**: `Python 3` (أو `Docker` مستخدماً `Dockerfile` الجاهز)
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
5. في قسم **Environment Variables** أضف المتغيرات من ملف `backend/.env.example`:
   - `ENVIRONMENT`: `production`
   - `DATABASE_URL`: `sqlite+aiosqlite:///marsa.db` (أو رابط PostgreSQL من Render إذا أردت Postgres مجاناً)
   - `ENCRYPTION_KEY`: (المفتاح السري المشفر من `.env`)
   - `JWT_PRIVATE_KEY`: (مفتاح RSA الخاص)
   - `JWT_PUBLIC_KEY`: (مفتاح RSA العام)
6. اضغط **Create Web Service**.
7. بعد انتهاء النشر، سيعطيك Render رابطاً مثل: `https://marsa-backend.onrender.com`.

---

## 4. ربط المكونات معاً (Connecting Everything)

1. خذ رابط الباك إند من Render: `https://marsa-backend.onrender.com`.
2. في Vercel الخاص بالموقع (`marsa-clinic`):
   - في كود `web/public/app.js`، الرابط سيتعرف تلقائياً أو يمكنك وضع المتغير في `window.MARSA_API_BASE`.
3. في Vercel الخاص بتطبيق فلاتر (`marsa-portal`):
   - في إعدادات **Settings -> Environment Variables**، تأكد من وضع:
     `API_BASE_URL` = `https://marsa-backend.onrender.com`
   - أعد النشر (Redeploy) ليعتمد فلاتر الرابط الجديد أثناء البناء.
