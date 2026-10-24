// Marsa Public Website JavaScript & Interactive Calendar
const API_BASE = window.MARSA_API_BASE 
  || localStorage.getItem('marsa_api_base')
  || (window.location.origin.includes(':8000') ? window.location.origin : null)
  || (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' ? 'http://localhost:8000' : (window.ENV_API_URL || 'https://api-marsa.onrender.com'));

const bookingModal = document.getElementById('publicBookingModal');
const btnOpenBooking = document.getElementById('btnOpenBookingModal');
const btnCloseBooking = document.getElementById('btnCloseBookingModal');
const btnCancelBooking = document.getElementById('btnCancelBookingModal');
const bookingForm = document.getElementById('publicBookingForm');
const bookTypeSelect = document.getElementById('bookType');

// Calendar State
let calCurrentDate = new Date(); // Africa/Cairo reference
let selectedCalDate = null;
let selectedTimeSlot = null;

const ARABIC_MONTHS = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
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

document.addEventListener('DOMContentLoaded', () => {
  loadTypes();
  initBookingModal();
  initCalendar();
  initScreeningTest();
});

async function loadTypes() {
  try {
    const res = await fetch(`${API_BASE}/appointments/types`);
    if (res.ok) {
      const types = await res.json();
      if (types && types.length > 0) {
        bookTypeSelect.innerHTML = types.map(t => `
          <option value="${t.type_id}">
            ${t.name_ar} (${t.duration_minutes} دقيقة — ${t.price_egp} ج.م)
          </option>
        `).join('');
        return;
      }
    }
  } catch (err) {
    console.warn('Could not load types from server, using fallback types:', err);
  }
  // Fallback with verified active database UUIDs
  bookTypeSelect.innerHTML = `
    <option value="41c617ef-a313-43f4-9812-b85c35f99bdf">كشف وتقييم نفسي أولي (60 دقيقة — 800 ج.م)</option>
    <option value="b23192df-aeae-4a11-b3ce-be0c324ee592">جلسة علاج معرفي سلوكي CBT (45 دقيقة — 600 ج.م)</option>
    <option value="f9a71352-7b90-4d61-bed6-f87bdbfbcfed">متابعة استشارية وتقييم دوائي (30 دقيقة — 500 ج.م)</option>
  `;
}

function initBookingModal() {
  btnOpenBooking.addEventListener('click', () => {
    bookingModal.classList.add('active');
    renderCalendar();
  });
  btnCloseBooking.addEventListener('click', () => bookingModal.classList.remove('active'));
  btnCancelBooking.addEventListener('click', () => bookingModal.classList.remove('active'));

  window.addEventListener('click', (e) => {
    if (e.target === bookingModal) bookingModal.classList.remove('active');
  });

  bookingForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const btnSubmit = document.getElementById('btnSubmitBooking');
    const name = document.getElementById('bookName').value.trim();
    const phone = document.getElementById('bookPhone').value.trim();
    const email = document.getElementById('bookEmail').value.trim();
    const typeId = bookTypeSelect.value;
    const notes = document.getElementById('bookNotes').value.trim();
    const preferredSlot = document.getElementById('selectedSlotDateTime').value;

    if (!preferredSlot) {
      alert('يرجى اختيار يوم وموعد الجلسة من التقويم قبل تأكيد الطلب.');
      return;
    }

    if (!name || !phone) {
      alert('يرجى ملء الاسم ورقم الهاتف.');
      return;
    }

    const originalBtnText = btnSubmit.textContent;
    btnSubmit.disabled = true;
    btnSubmit.textContent = 'جاري إرسال طلب الحجز...';

    try {
      const res = await fetch(`${API_BASE}/appointments/booking-requests`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          name: name,
          phone: phone,
          email: email || null,
          type_id: typeId,
          preferred_slot: preferredSlot,
          notes: notes || null
        })
      });

      if (res.ok) {
        bookingModal.classList.remove('active');
        bookingForm.reset();
        document.getElementById('selectedSlotBadge').style.display = 'none';
        document.getElementById('selectedSlotDateTime').value = '';
        selectedCalDate = null;
        selectedTimeSlot = null;
        alert('شكراً لك! تم استلام طلب حجز الموعد بنجاح.\nسيتواصل معك فريق الاستقبال لتأكيد الموعد في أقرب وقت.');
      } else {
        const errorData = await res.json().catch(() => ({}));
        let msg = 'حدث خطأ أثناء إرسال الطلب.';
        if (errorData.detail) {
          msg += '\nالتفاصيل: ' + (typeof errorData.detail === 'string' ? errorData.detail : JSON.stringify(errorData.detail));
        }
        alert(msg);
      }
    } catch (err) {
      console.error('Error submitting booking request:', err);
      alert('تعذر الاتصال بخادم الحجوزات. يرجى التأكد من تشغيل السيرفر أو التواصل مباشرة عبر الواتساب.');
    } finally {
      btnSubmit.disabled = false;
      btnSubmit.textContent = originalBtnText;
    }
  });
}

function initCalendar() {
  document.getElementById('btnCalPrev').addEventListener('click', () => {
    calCurrentDate.setMonth(calCurrentDate.getMonth() - 1);
    renderCalendar();
  });

  document.getElementById('btnCalNext').addEventListener('click', () => {
    calCurrentDate.setMonth(calCurrentDate.getMonth() + 1);
    renderCalendar();
  });

  renderCalendar();
}

function renderCalendar() {
  const monthTitle = document.getElementById('calMonthTitle');
  const daysGrid = document.getElementById('calDaysGrid');

  const year = calCurrentDate.getFullYear();
  const month = calCurrentDate.getMonth();

  monthTitle.textContent = `${ARABIC_MONTHS[month]} ${year}`;
  daysGrid.innerHTML = '';

  // First day of current month
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const totalDays = lastDay.getDate();

  // Arabic week starts on Saturday (JS getDay(): 0=Sun, 1=Mon, ..., 6=Sat)
  // Map JS day to Saturday-based index: Sat=0, Sun=1, Mon=2, Tue=3, Wed=4, Thu=5, Fri=6
  const jsDay = firstDay.getDay();
  const startOffset = (jsDay + 1) % 7;

  // Empty cells before first day
  for (let i = 0; i < startOffset; i++) {
    const empty = document.createElement('div');
    empty.className = 'cal-day-cell disabled';
    daysGrid.appendChild(empty);
  }

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Pre-select earliest available non-Friday date
  if (!selectedCalDate) {
    for (let dayOffset = 0; dayOffset < 30; dayOffset++) {
      const candidate = new Date(today.getFullYear(), today.getMonth(), today.getDate() + dayOffset);
      const isCandidateFriday = (candidate.getDay() + 1) % 7 === 6;
      if (!isCandidateFriday) {
        selectedCalDate = candidate;
        break;
      }
    }
  }

  // Render day cells
  for (let d = 1; d <= totalDays; d++) {
    const cellDate = new Date(year, month, d);
    const dayOfWeek = (cellDate.getDay() + 1) % 7; // 6 is Friday
    const isFriday = dayOfWeek === 6;
    const isPast = cellDate < today;

    const cell = document.createElement('div');
    cell.className = 'cal-day-cell';
    cell.textContent = d;

    if (isFriday) {
      cell.classList.add('disabled', 'friday');
      cell.title = 'عطلة العيادة الأسبوعية';
    } else if (isPast) {
      cell.classList.add('disabled');
    } else {
      // Check if selected
      if (selectedCalDate && 
          selectedCalDate.getFullYear() === year && 
          selectedCalDate.getMonth() === month && 
          selectedCalDate.getDate() === d) {
        cell.classList.add('selected');
      }

      cell.addEventListener('click', () => {
        selectedCalDate = new Date(year, month, d);
        selectedTimeSlot = null;
        document.querySelectorAll('.cal-day-cell').forEach(c => c.classList.remove('selected'));
        cell.classList.add('selected');
        renderTimeSlots();
      });
    }

    daysGrid.appendChild(cell);
  }

  renderTimeSlots();
}

function renderTimeSlots() {
  const container = document.getElementById('slotsGrid');
  const badge = document.getElementById('selectedSlotBadge');
  const badgeText = document.getElementById('selectedSlotText');
  const hiddenInput = document.getElementById('selectedSlotDateTime');

  container.innerHTML = '';

  if (!selectedCalDate) {
    container.innerHTML = '<span style="color:var(--text-muted); font-size:0.85rem;">يرجى اختيار يوم من التقويم أولاً</span>';
    badge.style.display = 'none';
    hiddenInput.value = '';
    return;
  }

  // Pre-select first slot if none selected yet
  if (!selectedTimeSlot && CLINIC_SLOTS.length > 0) {
    selectedTimeSlot = CLINIC_SLOTS[0].time24;
    const y = selectedCalDate.getFullYear();
    const m = String(selectedCalDate.getMonth() + 1).padStart(2, '0');
    const d = String(selectedCalDate.getDate()).padStart(2, '0');
    hiddenInput.value = `${y}-${m}-${d}T${selectedTimeSlot}:00+02:00`;
    const dateOptions = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
    const dateLabel = selectedCalDate.toLocaleDateString('ar-EG', dateOptions);
    badgeText.textContent = `الموعد المختار: ${dateLabel} — الساعة ${CLINIC_SLOTS[0].label}`;
    badge.style.display = 'flex';
  }

  CLINIC_SLOTS.forEach(slot => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'slot-btn';
    btn.textContent = slot.label;

    if (selectedTimeSlot === slot.time24) {
      btn.classList.add('active');
    }

    btn.addEventListener('click', () => {
      document.querySelectorAll('.slot-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      selectedTimeSlot = slot.time24;

      // Construct ISO datetime string for Africa/Cairo (UTC+2)
      const y = selectedCalDate.getFullYear();
      const m = String(selectedCalDate.getMonth() + 1).padStart(2, '0');
      const d = String(selectedCalDate.getDate()).padStart(2, '0');
      const isoSlot = `${y}-${m}-${d}T${slot.time24}:00+02:00`;
      hiddenInput.value = isoSlot;

      // Update readable badge
      const dateOptions = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
      const dateLabel = selectedCalDate.toLocaleDateString('ar-EG', dateOptions);
      badgeText.textContent = `الموعد المختار: ${dateLabel} — الساعة ${slot.label}`;
      badge.style.display = 'flex';
    });

    container.appendChild(btn);
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
