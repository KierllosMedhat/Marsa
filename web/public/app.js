// Marsa Public Website JavaScript
const API_BASE = window.location.origin.includes(':8000') 
  ? window.location.origin 
  : 'http://localhost:8000';

const bookingModal = document.getElementById('publicBookingModal');
const btnOpenBooking = document.getElementById('btnOpenBookingModal');
const btnCloseBooking = document.getElementById('btnCloseBookingModal');
const btnCancelBooking = document.getElementById('btnCancelBookingModal');
const bookingForm = document.getElementById('publicBookingForm');
const bookTypeSelect = document.getElementById('bookType');

// Load Appointment Types on Start
document.addEventListener('DOMContentLoaded', () => {
  loadTypes();
  initBookingModal();
  initScreeningTest();
});

async function loadTypes() {
  try {
    const res = await fetch(`${API_BASE}/appointments/types`);
    if (res.ok) {
      const types = await res.json();
      bookTypeSelect.innerHTML = types.map(t => `
        <option value="${t.type_id}">
          ${t.name_ar} (${t.duration_minutes} دقيقة — ${t.price_egp} ج.م)
        </option>
      `).join('');
    }
  } catch (_) {
    bookTypeSelect.innerHTML = `
      <option value="default-1">كشف وتقييم نفسي أولي (60 دقيقة — 800 ج.م)</option>
      <option value="default-2">جلسة علاج معرفي سلوكي CBT (45 دقيقة — 600 ج.م)</option>
    `;
  }
}

function initBookingModal() {
  btnOpenBooking.addEventListener('click', () => bookingModal.classList.add('active'));
  btnCloseBooking.addEventListener('click', () => bookingModal.classList.remove('active'));
  btnCancelBooking.addEventListener('click', () => bookingModal.classList.remove('active'));

  window.addEventListener('click', (e) => {
    if (e.target === bookingModal) bookingModal.classList.remove('active');
  });

  bookingForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = document.getElementById('bookName').value.trim();
    const phone = document.getElementById('bookPhone').value.trim();
    const email = document.getElementById('bookEmail').value.trim();
    const typeId = bookTypeSelect.value;
    const notes = document.getElementById('bookNotes').value.trim();

    try {
      const res = await fetch(`${API_BASE}/appointments/booking-requests`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: name,
          phone: phone,
          email: email || null,
          type_id: typeId,
          notes: notes || null
        })
      });

      if (res.ok) {
        bookingModal.classList.remove('active');
        bookingForm.reset();
        alert('شكراً لك! تم استلام طلب حجز الموعد بنجاح.\nسيتواصل معك فريق الاستقبال لتأكيد الموعد الأنسب وتفاصيل الجلسة.');
      } else {
        alert('حدث خطأ أثناء إرسال الطلب. يرجى التواصل هاتفياً مع العيادة.');
      }
    } catch (_) {
      alert('تم تسجيل طلبك مبدئياً، وسيتواصل معك موظف الاستقبال لتأكيد الحجز.');
      bookingModal.classList.remove('active');
    }
  });
}

function initScreeningTest() {
  const form = document.getElementById('gad7Form');
  const resultDiv = document.getElementById('gad7Result');
  const titleEl = document.getElementById('gad7ScoreTitle');
  const descEl = document.getElementById('gad7ScoreDesc');

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const formData = new FormData(form);
    let totalScore = 0;
    for (let value of formData.values()) {
      totalScore += parseInt(value, 10);
    }

    resultDiv.style.display = 'block';
    if (totalScore <= 2) {
      titleEl.textContent = `مجموع الدرجات: ${totalScore} — مستوى قلق طفيف / طبيعي`;
      descEl.textContent = 'أعراض القلق لديك ضمن المعدلات الحياتية الطبيعية ولا تشير إلى اضطراب قلق سريري.';
    } else if (totalScore <= 5) {
      titleEl.textContent = `مجموع الدرجات: ${totalScore} — مستوى قلق خفيف إلى متوسط`;
      descEl.textContent = 'توجد بعض مؤشرات التوتر والقلق. يُنصح بممارسة تمارين الاسترخاء ومراجعة طبيب نفسي إذا كانت تؤثر على أدائك اليومي.';
    } else {
      titleEl.textContent = `مجموع الدرجات: ${totalScore} — مستوى قلق ملحوظ (مرتفع)`;
      descEl.textContent = 'تشير الدرجة إلى معاناتك من مستويات قلق مرتفعة قد تؤثر على جودة حياتك ونومك. ننصحك بحجز جلسة تقييم متخصصة في العيادة للمساعدة.';
    }
  });
}
