'use client';

import React, { useEffect, useState } from 'react';

interface AppointmentType {
  type_id: string;
  name_ar: string;
  duration_minutes: number;
  price_egp: number;
}

const ARABIC_MONTHS = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const CLINIC_SLOTS = [
  { time24: '14:00', label: '02:00 م' },
  { time24: '15:00', label: '03:00 م' },
  { time24: '16:00', label: '04:00 م' },
  { time24: '17:00', label: '05:00 م' },
  { time24: '18:00', label: '06:00 م' },
  { time24: '19:00', label: '07:00 م' },
  { time24: '20:00', label: '08:00 م' },
];

export default function HomePage() {
  const [modalOpen, setModalOpen] = useState(false);
  const [types, setTypes] = useState<AppointmentType[]>([
    {
      type_id: '41c617ef-a313-43f4-9812-b85c35f99bdf',
      name_ar: 'كشف وتقييم نفسي أولي',
      duration_minutes: 60,
      price_egp: 800,
    },
    {
      type_id: 'b23192df-aeae-4a11-b3ce-be0c324ee592',
      name_ar: 'جلسة علاج معرفي سلوكي (CBT)',
      duration_minutes: 45,
      price_egp: 600,
    },
    {
      type_id: 'f9a71352-7b90-4d61-bed6-f87bdbfbcfed',
      name_ar: 'متابعة استشارية وتقييم دوائي',
      duration_minutes: 30,
      price_egp: 500,
    },
  ]);

  // Booking form state
  const [bookName, setBookName] = useState('');
  const [bookPhone, setBookPhone] = useState('');
  const [bookEmail, setBookEmail] = useState('');
  const [bookTypeId, setBookTypeId] = useState(
    '41c617ef-a313-43f4-9812-b85c35f99bdf'
  );
  const [bookNotes, setBookNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [bookingSuccessMsg, setBookingSuccessMsg] = useState<string | null>(
    null
  );

  // Calendar state
  const [calMonth, setCalMonth] = useState(() => new Date().getMonth());
  const [calYear, setCalYear] = useState(() => new Date().getFullYear());
  const [selectedDate, setSelectedDate] = useState<Date>(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    for (let i = 0; i < 30; i++) {
      const cand = new Date(
        today.getFullYear(),
        today.getMonth(),
        today.getDate() + i
      );
      if ((cand.getDay() + 1) % 7 !== 6) return cand; // Skip Friday
    }
    return today;
  });
  const [selectedSlot, setSelectedSlot] = useState<string>('14:00');

  // GAD-7 Screening state
  const [gad1, setGad1] = useState<number | null>(null);
  const [gad2, setGad2] = useState<number | null>(null);
  const [gad3, setGad3] = useState<number | null>(null);
  const [gadResult, setGadResult] = useState<{
    title: string;
    desc: string;
  } | null>(null);

  useEffect(() => {
    fetch('/api/appointments/types')
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (Array.isArray(data) && data.length > 0) {
          setTypes(data);
          setBookTypeId(data[0].type_id);
        }
      })
      .catch(() => {});
  }, []);

  const handlePrevMonth = () => {
    if (calMonth === 0) {
      setCalMonth(11);
      setCalYear((y) => y - 1);
    } else {
      setCalMonth((m) => m - 1);
    }
  };

  const handleNextMonth = () => {
    if (calMonth === 11) {
      setCalMonth(0);
      setCalYear((y) => y + 1);
    } else {
      setCalMonth((m) => m + 1);
    }
  };

  const getPreferredSlotIso = () => {
    const y = selectedDate.getFullYear();
    const m = String(selectedDate.getMonth() + 1).padStart(2, '0');
    const d = String(selectedDate.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}T${selectedSlot}:00+02:00`;
  };

  const getSelectedSlotReadable = () => {
    const dateLabel = selectedDate.toLocaleDateString('ar-EG', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
    const slotObj = CLINIC_SLOTS.find((s) => s.time24 === selectedSlot);
    return `الموعد المختار: ${dateLabel} — الساعة ${slotObj?.label || selectedSlot}`;
  };

  const handleBookingSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!bookName.trim() || !bookPhone.trim()) {
      alert('يرجى ملء الاسم ورقم الهاتف.');
      return;
    }

    setSubmitting(true);
    setBookingSuccessMsg(null);
    try {
      const res = await fetch('/api/appointments/booking-requests', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: bookName.trim(),
          phone: bookPhone.trim(),
          email: bookEmail.trim() || null,
          type_id: bookTypeId,
          preferred_slot: getPreferredSlotIso(),
          notes: bookNotes.trim() || null,
        }),
      });

      if (res.ok) {
        const data = await res.json().catch(() => ({}));
        setBookName('');
        setBookPhone('');
        setBookEmail('');
        setBookNotes('');
        const mrnPart = data.patient_mrn
          ? ` (رقم الملف الطبي: ${data.patient_mrn})`
          : '';
        setBookingSuccessMsg(
          `شكراً لك! تم تسجيل موعدك مباشرةً في نظام بوابة العيادة${mrnPart}. يمكنك الآن رؤيته فوراً في جدول مواعيد الطبيب والاستقبال.`
        );
      } else {
        const err = await res.json().catch(() => ({}));
        alert(err.detail || 'حدث خطأ أثناء إرسال الطلب.');
      }
    } catch {
      alert('تعذر إرسال الطلب حالياً. يرجى المحاولة مرة أخرى.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleGadSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (gad1 === null || gad2 === null || gad3 === null) return;
    const total = gad1 + gad2 + gad3;
    if (total <= 2) {
      setGadResult({
        title: `مجموع الدرجات: ${total} — مستوى قلق طفيف / طبيعي`,
        desc: 'أعراض القلق لديك ضمن المعدلات الحياتية الطبيعية ولا تشير إلى اضطراب قلق سريري.',
      });
    } else if (total <= 5) {
      setGadResult({
        title: `مجموع الدرجات: ${total} — مستوى قلق خفيف إلى متوسط`,
        desc: 'توجد بعض مؤشرات التوتر والقلق. يُنصح بممارسة تمارين الاسترخاء ومراجعة طبيب نفسي إذا كانت تؤثر على أدائك اليومي.',
      });
    } else {
      setGadResult({
        title: `مجموع الدرجات: ${total} — مستوى قلق ملحوظ (مرتفع)`,
        desc: 'تشير الدرجة إلى معاناتك من مستويات قلق مرتفعة قد تؤثر على جودة حياتك ونومك. ننصحك بحجز جلسة تقييم متخصصة في العيادة للمساعدة.',
      });
    }
  };

  // Calendar grid computation
  const firstDay = new Date(calYear, calMonth, 1);
  const totalDays = new Date(calYear, calMonth + 1, 0).getDate();
  const startOffset = (firstDay.getDay() + 1) % 7;
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return (
    <>
      {/* Header */}
      <header>
        <div className="header-container">
          <a href="#" className="brand">
            <img
              src="/assets/logo.jpg"
              alt="شعار عيادة مرساة"
              className="brand-logo"
            />
            <div className="brand-info">
              <span className="brand-title">عيادة مرساة</span>
              <span className="brand-subtitle">
                د. مارينا نبيه نمر — سوهاج
              </span>
            </div>
          </a>

          <ul className="nav-links">
            <li>
              <a href="#services">خدمات العيادة</a>
            </li>
            <li>
              <a href="#doctor">عن الطبيب</a>
            </li>
            <li>
              <a href="#screening">التقييم النفسي الذاتي</a>
            </li>
            <li>
              <a href="#location">العنوان والمواعيد</a>
            </li>
            <li>
              <a
                href="/portal"
                style={{ color: 'var(--primary)', fontWeight: 700 }}
              >
                🩺 بوابة العيادة
              </a>
            </li>
          </ul>

          <div className="header-cta" style={{ display: 'flex', gap: '8px' }}>
            <a
              href="/portal"
              className="btn btn-outline"
              style={{ padding: '8px 14px', fontSize: '0.88rem' }}
            >
              🩺 بوابة الطبيب
            </a>
            <button
              className="btn btn-primary"
              onClick={() => {
                setBookingSuccessMsg(null);
                setModalOpen(true);
              }}
            >
              احجز استشارتك الآن
            </button>
          </div>
        </div>
        <div className="mobile-nav-bar">
          <a href="#services">الخدمات</a>
          <a href="#doctor">عن الطبيب</a>
          <a href="#screening">التقييم الذاتي</a>
          <a href="#location">العنوان</a>
          <a href="/portal" style={{ color: 'var(--primary)', fontWeight: 700 }}>
            🩺 بوابة العيادة
          </a>
        </div>
      </header>

      {/* Hero Section */}
      <section className="hero">
        <div className="hero-container">
          <span className="hero-badge">مساحة آمنة وسرية تامة</span>
          <h2>عيادة مرساة — د. مارينا نبيه نمر</h2>
          <p>
            أخصائي الطب النفسي وعلاج الإدمان (سوهاج) — برامج علاجية متكاملة تشمل
            العلاج الدوائي المتقدم والعلاج المعرفي السلوكي (CBT)، بمقاربة علمية
            وإنسانية ترتكز على الخصوصية والتعافي المستدام.
          </p>
          <div className="hero-actions">
            <button
              className="btn btn-primary"
              onClick={() => {
                setBookingSuccessMsg(null);
                setModalOpen(true);
              }}
            >
              📅 احجز استشارتك في العيادة
            </button>
            <a
              href="https://wa.me/qr/F2QRTFS2PZAIJ1?s=v"
              target="_blank"
              rel="noreferrer"
              className="btn btn-outline"
              style={{ borderColor: '#25D366', color: '#1E6B37' }}
            >
              💬 تواصل واتساب سريع
            </a>
            <a href="#screening" className="btn btn-outline">
              📝 الفحص النفسي الذاتي
            </a>
          </div>
        </div>
      </section>

      {/* Services Section */}
      <section id="services">
        <div className="section-header">
          <h2 className="section-title">مجالات التقييم والرعاية الإكلينيكية</h2>
          <p className="section-subtitle">
            نقدم خدمات علاجية متكاملة وفق أحدث الدلائل الإرشادية العالمية
          </p>
        </div>

        <div className="grid-3">
          <div className="card">
            <div className="card-icon">🧠</div>
            <h3>اضطرابات القلق ونوبات الهلع</h3>
            <p>
              تشخيص وعلاج نوبات الهلع الفجائية، القلق المعمم، والرهاب الاجتماعي عبر
              بروتوكولات متكاملة تجمع بين التنظيم الدوائي وجلسات الاسترخاء
              والتعرض.
            </p>
          </div>

          <div className="card">
            <div className="card-icon">🌧️</div>
            <h3>نوبات الاكتئاب واضطرابات المزاج</h3>
            <p>
              رعاية شاملة للاكتئاب الحاد والمزمن، اضطراب ثنائي القطب، مع التركيز
              على استعادة الطاقة الحيوية والدافعية ونوعية الحياة اليومية.
            </p>
          </div>

          <div className="card">
            <div className="card-icon">🔄</div>
            <h3>اضطراب الوسواس القهري (OCD)</h3>
            <p>
              برامج متخصصة في العلاج بالتعرض ومنع الاستجابة (ERP) للتعامل الفعال مع
              الأفكار الإلحاحية والسلوكيات التكرارية القهرية.
            </p>
          </div>

          <div className="card">
            <div className="card-icon">💊</div>
            <h3>الاستشارات والضبط الدوائي</h3>
            <p>
              تقييم دقيق للحاجة الدوائية، اختيار العلاج الأنسب، ومتابعة دقيقة
              للأعراض الجانبية والجرعات بأعلى معايير الأمان الطبي.
            </p>
          </div>

          <div className="card">
            <div className="card-icon">🗣️</div>
            <h3>العلاج المعرفي السلوكي (CBT)</h3>
            <p>
              جلسات فردية تهدف إلى تعديل أنماط التفكير السلبية وتطوير مهارات
              التأقلم مع الضغوط المهنية والحياتية المعقدة.
            </p>
          </div>

          <div className="card">
            <div className="card-icon">🛡️</div>
            <h3>سرية تامة وملف مشفر</h3>
            <p>
              جميع بياناتك وملفاتك السريرية مشفرة بالكامل بأحدث تقنيات التشفير،
              ومحمية ببروتوكولات سرية طبية صارمة.
            </p>
          </div>
        </div>
      </section>

      {/* Doctor Profile Section */}
      <section id="doctor">
        <div className="section-header">
          <h2 className="section-title">الطبيب المعالج</h2>
          <p className="section-subtitle">
            خبرة إكلينيكية متخصصة في الطب النفسي وعلاج الإدمان
          </p>
        </div>

        <div className="doctor-profile">
          <div className="doctor-avatar">
            <img
              src="/assets/fb_profile.jpg"
              alt="د. مارينا نبيه نمر — عيادة مرساة"
            />
          </div>
          <div>
            <h3
              style={{
                fontSize: '1.8rem',
                color: 'var(--primary)',
                marginBottom: '6px',
              }}
            >
              د. مارينا نبيه نمر
            </h3>
            <p
              style={{
                fontWeight: 700,
                color: 'var(--primary-light)',
                marginBottom: '14px',
                fontSize: '1.1rem',
              }}
            >
              أخصائي الطب النفسي وعلاج الإدمان
            </p>
            <p
              style={{
                color: 'var(--text-muted)',
                marginBottom: '16px',
                lineHeight: 1.8,
              }}
            >
              نؤمن في &quot;مرساة&quot; أن الطب النفسي ليس مجرد وصفة دوائية، بل
              مساحة آمنة ورحلة علاجية قائمة على الإنصات الفاحص والتشخيص العلمي
              الدقيق، لفهم السياق الإنساني لكل شخص ووضع خطة علاجية متكاملة تشمل
              العلاج الدوائي والدعم المعرفي السلوكي وفق أعلى معايير الخصوصية
              والسرية التامة.
            </p>
            <div
              style={{
                display: 'flex',
                gap: '8px',
                flexWrap: 'wrap',
                marginBottom: '18px',
              }}
            >
              <span
                style={{
                  background: '#F1F5F9',
                  padding: '6px 14px',
                  borderRadius: '8px',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                }}
              >
                الطب النفسي العام
              </span>
              <span
                style={{
                  background: '#F1F5F9',
                  padding: '6px 14px',
                  borderRadius: '8px',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                }}
              >
                علاج الإدمان والتعافي
              </span>
              <span
                style={{
                  background: '#F1F5F9',
                  padding: '6px 14px',
                  borderRadius: '8px',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                }}
              >
                اضطرابات القلق والاكتئاب
              </span>
              <span
                style={{
                  background: '#F1F5F9',
                  padding: '6px 14px',
                  borderRadius: '8px',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                }}
              >
                العلاج المعرفي السلوكي (CBT)
              </span>
            </div>
            <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
              <a
                href="https://wa.me/qr/F2QRTFS2PZAIJ1?s=v"
                target="_blank"
                rel="noreferrer"
                className="btn btn-primary"
                style={{
                  background: '#25D366',
                  border: 'none',
                  fontSize: '0.88rem',
                }}
              >
                <span>💬 تواصل عبر واتساب</span>
              </a>
              <a
                href="https://www.facebook.com/share/1CMFZxdUCJ"
                target="_blank"
                rel="noreferrer"
                className="btn btn-outline"
                style={{
                  borderColor: '#1877F2',
                  color: '#1877F2',
                  fontSize: '0.88rem',
                }}
              >
                <span>🌐 صفحة الفيسبوك الرسمية</span>
              </a>
              <a
                href="https://linktr.ee/Marsa_Clinic"
                target="_blank"
                rel="noreferrer"
                className="btn btn-outline"
                style={{ fontSize: '0.88rem' }}
              >
                <span>🔗 Linktree العيادة</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Screening Section */}
      <section id="screening">
        <div className="section-header">
          <h2 className="section-title">التقييم النفسي الذاتي الاسترشادي</h2>
          <p className="section-subtitle">
            مقاييس علمية عالمية معتمدة لمساعدتك على تقييم أعراضك
          </p>
        </div>

        <div className="disclaimer-box">
          <strong>⚠️ تنبيه طبي هام:</strong> هذه الاستبيانات هي أدوات فحص
          استرشادية مبنية على مقاييس مقننة عالمياً (PHQ-9 و GAD-7)، ولا تُعد
          تشخيصاً طبياً نهائياً ولا تُغني عن الاستشارة السريرية المباشرة مع
          الطبيب النفسي.
        </div>

        <div className="test-card">
          <h3 style={{ color: 'var(--primary)', marginBottom: '8px' }}>
            مقياس القلق النفسي العام (GAD-7)
          </h3>
          <p
            style={{
              color: 'var(--text-muted)',
              fontSize: '0.9rem',
              marginBottom: '20px',
            }}
          >
            خلال الأسبوعين الماضيين، كم مرة شعرت بالانزعاج من المشاكل التالية؟
          </p>

          <form onSubmit={handleGadSubmit}>
            <div className="question-box">
              <p className="question-title">
                1. الشعور بالعصبية أو القلق أو التوتر الشديد:
              </p>
              <div className="options-group">
                {[
                  { val: 0, label: 'أبداً (0)' },
                  { val: 1, label: 'عدة أيام (1)' },
                  { val: 2, label: 'أكثر من نصف الأيام (2)' },
                  { val: 3, label: 'كل يوم تقريباً (3)' },
                ].map((opt) => (
                  <label key={opt.val} className="option-label">
                    <input
                      type="radio"
                      name="g1"
                      value={opt.val}
                      required
                      checked={gad1 === opt.val}
                      onChange={() => setGad1(opt.val)}
                    />
                    <span>{opt.label}</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="question-box">
              <p className="question-title">
                2. عدم القدرة على إيقاف أو التحكم في القلق الزائد:
              </p>
              <div className="options-group">
                {[
                  { val: 0, label: 'أبداً (0)' },
                  { val: 1, label: 'عدة أيام (1)' },
                  { val: 2, label: 'أكثر من نصف الأيام (2)' },
                  { val: 3, label: 'كل يوم تقريباً (3)' },
                ].map((opt) => (
                  <label key={opt.val} className="option-label">
                    <input
                      type="radio"
                      name="g2"
                      value={opt.val}
                      required
                      checked={gad2 === opt.val}
                      onChange={() => setGad2(opt.val)}
                    />
                    <span>{opt.label}</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="question-box">
              <p className="question-title">
                3. القلق المفرط بشأن أمور مختلفة ومتباعدة:
              </p>
              <div className="options-group">
                {[
                  { val: 0, label: 'أبداً (0)' },
                  { val: 1, label: 'عدة أيام (1)' },
                  { val: 2, label: 'أكثر من نصف الأيام (2)' },
                  { val: 3, label: 'كل يوم تقريباً (3)' },
                ].map((opt) => (
                  <label key={opt.val} className="option-label">
                    <input
                      type="radio"
                      name="g3"
                      value={opt.val}
                      required
                      checked={gad3 === opt.val}
                      onChange={() => setGad3(opt.val)}
                    />
                    <span>{opt.label}</span>
                  </label>
                ))}
              </div>
            </div>

            <button
              type="submit"
              className="btn btn-primary"
              style={{ marginTop: '10px' }}
            >
              احسب نتيجة مقياس القلق
            </button>
          </form>

          {gadResult && (
            <div
              style={{
                marginTop: '20px',
                padding: '16px',
                borderRadius: '10px',
                background: '#ECFDF5',
                border: '1px solid #A7F3D0',
              }}
            >
              <h4
                style={{
                  color: '#065F46',
                  fontSize: '1.1rem',
                  marginBottom: '6px',
                }}
              >
                {gadResult.title}
              </h4>
              <p style={{ color: '#047857', fontSize: '0.95rem' }}>
                {gadResult.desc}
              </p>
            </div>
          )}
        </div>
      </section>

      {/* Location & Hours */}
      <section id="location">
        <div className="section-header">
          <h2 className="section-title">موقع العيادة ومواعيد العمل</h2>
          <p className="section-subtitle">
            نرحب بكم بمواعيد حجز مسبقة لضمان الراحة والخصوصية
          </p>
        </div>

        <div className="grid-3">
          <div className="card">
            <h3>📍 العنوان</h3>
            <p>
              <strong>سوهاج، جمهورية مصر العربية:</strong>
              <br />
              شارع بسطا المتفرع من شارع المحطة، عيادات رويال، الدور الثاني.
              <br />
              <span style={{ color: 'var(--text-muted)', fontSize: '0.88rem' }}>
                (أمام مستشفى جريت توماس — أعلى مقهى فرساي)
              </span>
            </p>
          </div>
          <div className="card">
            <h3>⏰ مواعيد العمل</h3>
            <p>
              السبت إلى الأربعاء: 2:00 ظهراً – 9:00 مساءً
              <br />
              الخميس: 12:00 ظهراً – 6:00 مساءً
              <br />
              الجمعة: عطلة العيادة الأسبوعية
            </p>
          </div>
          <div className="card">
            <h3>📞 للتواصل والاستفسار</h3>
            <p>
              واتساب العيادة:{' '}
              <a
                href="https://wa.me/qr/F2QRTFS2PZAIJ1?s=v"
                target="_blank"
                rel="noreferrer"
                style={{
                  color: '#25D366',
                  fontWeight: 'bold',
                  textDecoration: 'none',
                }}
              >
                مراسلة فورية ↗
              </a>
              <br />
              فيسبوك:{' '}
              <a
                href="https://www.facebook.com/share/1CMFZxdUCJ"
                target="_blank"
                rel="noreferrer"
                style={{ color: '#1877F2', textDecoration: 'none' }}
              >
                عيادة مرساة - د/مارينا نبيه نمر ↗
              </a>
              <br />
              توقيت الحجوزات: بتوقيت القاهرة (GMT+2)
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer>
        <div className="footer-container">
          <div>
            <h3 style={{ fontSize: '1.3rem', marginBottom: '12px' }}>
              مرساة للطب النفسي
            </h3>
            <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '0.9rem' }}>
              ملاذك الآمن للتعافي النفسي، بإشراف طبي متخصص وسرية تامة.
            </p>
          </div>
          <div>
            <h4 style={{ marginBottom: '12px' }}>روابط وتواصل</h4>
            <ul style={{ listStyle: 'none', lineHeight: 2 }}>
              <li>
                <a
                  href="#services"
                  style={{
                    color: 'rgba(255,255,255,0.7)',
                    textDecoration: 'none',
                  }}
                >
                  الخدمات الإكلينيكية
                </a>
              </li>
              <li>
                <a
                  href="#doctor"
                  style={{
                    color: 'rgba(255,255,255,0.7)',
                    textDecoration: 'none',
                  }}
                >
                  عن د. مارينا نبيه
                </a>
              </li>
              <li>
                <a
                  href="#screening"
                  style={{
                    color: 'rgba(255,255,255,0.7)',
                    textDecoration: 'none',
                  }}
                >
                  الفحص النفسي الذاتي
                </a>
              </li>
              <li>
                <a
                  href="/portal"
                  style={{
                    color: '#DFAC47',
                    textDecoration: 'none',
                    fontWeight: 700,
                  }}
                >
                  🩺 بوابة الكادر الطبي (Flutter App) ↗
                </a>
              </li>
            </ul>
          </div>
          <div>
            <h4 style={{ marginBottom: '12px' }}>سياسات الحجز والسرية</h4>
            <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '0.85rem' }}>
              تخضع جميع المواعيد لسياسة الإلغاء قبل 24 ساعة. كافة السجلات
              السريرية مشفرة ببروتوكولات طبية آمنة لحماية خصوصيتك التامة.
            </p>
          </div>
        </div>
        <div className="footer-bottom">
          جميع الحقوق محفوظة © 2026 عيادة مرساة للطب النفسي والعلاج المعرفي
          السلوكي
        </div>
      </footer>

      {/* Modal: Public Appointment Booking */}
      <div className={`modal-overlay ${modalOpen ? 'active' : ''}`}>
        <div className="modal">
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '16px',
            }}
          >
            <h3 style={{ color: 'var(--primary)' }}>طلب حجز موعد في العيادة</h3>
            <button
              type="button"
              style={{
                background: 'none',
                border: 'none',
                fontSize: '1.2rem',
                cursor: 'pointer',
              }}
              onClick={() => setModalOpen(false)}
            >
              ✕
            </button>
          </div>

          {bookingSuccessMsg ? (
            <div style={{ textAlign: 'center', padding: '24px 12px' }}>
              <div style={{ fontSize: '3rem', marginBottom: '12px' }}>✅</div>
              <h4
                style={{
                  color: 'var(--primary)',
                  fontSize: '1.2rem',
                  marginBottom: '10px',
                }}
              >
                تم تسجيل طلب الحجز بنجاح
              </h4>
              <p
                style={{
                  color: 'var(--text-muted)',
                  marginBottom: '20px',
                  fontSize: '0.95rem',
                }}
              >
                {bookingSuccessMsg}
              </p>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'center',
                  gap: '10px',
                  flexWrap: 'wrap',
                }}
              >
                <a href="/portal" className="btn btn-primary">
                  🩺 فتح بوابة العيادة الآن
                </a>
                <button
                  type="button"
                  className="btn btn-outline"
                  onClick={() => setModalOpen(false)}
                >
                  إغلاق
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleBookingSubmit}>
              <div className="form-group">
                <label>الاسم بالكامل *</label>
                <input
                  type="text"
                  className="form-control"
                  required
                  placeholder="مثال: يوسف أحمد"
                  value={bookName}
                  onChange={(e) => setBookName(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label>رقم الهاتف المحمول (مصر) *</label>
                <input
                  type="tel"
                  className="form-control"
                  required
                  placeholder="01012345678"
                  dir="ltr"
                  value={bookPhone}
                  onChange={(e) => setBookPhone(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label>البريد الإلكتروني (لتأكيد الموعد)</label>
                <input
                  type="email"
                  className="form-control"
                  placeholder="user@example.com"
                  dir="ltr"
                  value={bookEmail}
                  onChange={(e) => setBookEmail(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label>نوع الجلسة المطلوبة *</label>
                <select
                  className="form-control"
                  required
                  value={bookTypeId}
                  onChange={(e) => setBookTypeId(e.target.value)}
                >
                  {types.map((t) => (
                    <option key={t.type_id} value={t.type_id}>
                      {t.name_ar} ({t.duration_minutes} دقيقة — {t.price_egp} ج.م)
                    </option>
                  ))}
                </select>
              </div>

              {/* Interactive Calendar & Time Slots */}
              <div className="calendar-picker-box">
                <div className="calendar-header">
                  <span className="calendar-month-title">
                    {ARABIC_MONTHS[calMonth]} {calYear}
                  </span>
                  <div style={{ display: 'flex', gap: '4px' }}>
                    <button
                      type="button"
                      className="btn-cal-nav"
                      onClick={handlePrevMonth}
                    >
                      ›
                    </button>
                    <button
                      type="button"
                      className="btn-cal-nav"
                      onClick={handleNextMonth}
                    >
                      ‹
                    </button>
                  </div>
                </div>

                <div className="calendar-weekdays">
                  <span>سبت</span>
                  <span>أحد</span>
                  <span>إثنين</span>
                  <span>ثلاثاء</span>
                  <span>أربعاء</span>
                  <span>خميس</span>
                  <span style={{ color: '#EF4444' }}>جمعة</span>
                </div>

                <div className="calendar-days-grid">
                  {Array.from({ length: startOffset }).map((_, idx) => (
                    <div key={`empty-${idx}`} className="cal-day-cell disabled" />
                  ))}
                  {Array.from({ length: totalDays }).map((_, idx) => {
                    const dayNum = idx + 1;
                    const cellDate = new Date(calYear, calMonth, dayNum);
                    const isFriday = (cellDate.getDay() + 1) % 7 === 6;
                    const isPast = cellDate < today;
                    const isSelected =
                      selectedDate.getFullYear() === calYear &&
                      selectedDate.getMonth() === calMonth &&
                      selectedDate.getDate() === dayNum;

                    const classes = ['cal-day-cell'];
                    if (isFriday) classes.push('disabled', 'friday');
                    else if (isPast) classes.push('disabled');
                    else if (isSelected) classes.push('selected');

                    return (
                      <div
                        key={dayNum}
                        className={classes.join(' ')}
                        title={isFriday ? 'عطلة العيادة الأسبوعية' : undefined}
                        onClick={() => {
                          if (!isFriday && !isPast) {
                            setSelectedDate(new Date(calYear, calMonth, dayNum));
                          }
                        }}
                      >
                        {dayNum}
                      </div>
                    );
                  })}
                </div>

                <div style={{ marginTop: '14px' }}>
                  <label
                    style={{
                      fontSize: '0.85rem',
                      fontWeight: 600,
                      color: 'var(--primary)',
                    }}
                  >
                    اختر توقيت الجلسة (بتوقيت القاهرة) *
                  </label>
                  <div className="slots-grid">
                    {CLINIC_SLOTS.map((slot) => (
                      <button
                        key={slot.time24}
                        type="button"
                        className={`slot-btn ${
                          selectedSlot === slot.time24 ? 'active' : ''
                        }`}
                        onClick={() => setSelectedSlot(slot.time24)}
                      >
                        {slot.label}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="selected-appointment-badge">
                  <span>🗓️</span>
                  <span>{getSelectedSlotReadable()}</span>
                </div>
              </div>

              <div className="form-group">
                <label>ملاحظات إضافية (اختياري)</label>
                <input
                  type="text"
                  className="form-control"
                  placeholder="أي تفاصيل ترغب في مشاركتها مسبقاً مع العيادة..."
                  value={bookNotes}
                  onChange={(e) => setBookNotes(e.target.value)}
                />
              </div>

              <div
                style={{
                  display: 'flex',
                  justifyContent: 'flex-end',
                  gap: '10px',
                  marginTop: '20px',
                }}
              >
                <button
                  type="button"
                  className="btn btn-outline"
                  onClick={() => setModalOpen(false)}
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={submitting}
                >
                  {submitting ? 'جاري إرسال طلب الحجز...' : 'تأكيد طلب الحجز'}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </>
  );
}
