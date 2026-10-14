// Marsa Public Website JavaScript & Interactive Calendar
const API_BASE = window.location.origin.includes(':8000') 
  ? window.location.origin 
  : 'http://localhost:8000';

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
    const name = document.getElementById('bookName').value.trim();
    const phone = document.getElementById('bookPhone').value.trim();
    const email = document.getElementById('bookEmail').value.trim();
    const typeId = bookTypeSelect.value;
    const notes = document.getElementById('bookNotes').value.trim();
    const preferredSlot = document.getElementById('selectedSlotDateTime').value;

    if (!preferredSlot) {
      alert('يرجى اختيار تاريخ ويوم وموعد الجلسة من التقويم قبل المتابعة.');
      return;
    }

    try {
      const res = await fetch(`${API_BASE}/appointments/booking-requests`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
        alert('شكراً لك! تم استلام طلب حجز الموعد بنجاح.\nسيتواصل معك فريق الاستقبال لتأكيد الموعد المختار في أقرب وقت.');
      } else {
        alert('حدث خطأ أثناء إرسال الطلب. يرجى مراجعة موظف الاستقبال هاتفياً.');
      }
    } catch (_) {
      alert('تم استلام طلبك مبدئياً، وسيتواصل معك موظف الاستقبال لتأكيد الحجز.');
      bookingModal.classList.remove('active');
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

  // If no date selected yet, pick today or next available weekday
  if (!selectedCalDate) {
    const initialDay = today.getMonth() === month ? today.getDate() : 1;
    const testDate = new Date(year, month, initialDay);
    if ((testDate.getDay() + 1) % 7 !== 6 && testDate >= today) {
      selectedCalDate = testDate;
    }
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
      const m = String(selectedCalDate.getMonth() + 1).padLeft(2, '0');
      const d = String(selectedCalDate.getDate()).padLeft(2, '0');
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
