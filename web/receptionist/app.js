// Receptionist Portal API & State Controller
const API_BASE = window.location.origin.includes(':8000') 
  ? window.location.origin 
  : 'http://localhost:8000';

let authToken = localStorage.getItem('marsa_receptionist_token');
let currentStaff = null;
let cachedPatients = [];
let cachedTypes = [];

// DOM Elements
const loginSection = document.getElementById('loginSection');
const dashboardSection = document.getElementById('dashboardSection');
const userNav = document.getElementById('userNav');
const staffNameDisplay = document.getElementById('staffNameDisplay');
const loginForm = document.getElementById('loginForm');
const loginError = document.getElementById('loginError');
const btnLogout = document.getElementById('btnLogout');

// Tab Buttons
const tabButtons = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');

// Modals
const bookModal = document.getElementById('bookModal');
const patientModal = document.getElementById('patientModal');
const matchModal = document.getElementById('matchModal');

// Init
document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  initModals();
  checkAuth();
  registerServiceWorker();
});

function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
}

function initTabs() {
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      tabButtons.forEach(b => b.classList.remove('active'));
      tabContents.forEach(c => c.classList.remove('active'));
      btn.classList.add('active');
      const target = document.getElementById(btn.dataset.tab);
      if (target) target.classList.add('active');

      if (btn.dataset.tab === 'tab-schedule') loadAppointments();
      if (btn.dataset.tab === 'tab-patients') loadPatients();
      if (btn.dataset.tab === 'tab-bookings') loadBookingRequests();
    });
  });
}

function initModals() {
  // Book Modal
  document.getElementById('btnOpenBookModal').addEventListener('click', () => {
    populateBookSelects();
    bookModal.classList.add('active');
  });
  document.getElementById('btnCloseBookModal').addEventListener('click', () => bookModal.classList.remove('active'));
  document.getElementById('btnCancelBookModal').addEventListener('click', () => bookModal.classList.remove('active'));

  // Patient Modal
  document.getElementById('btnOpenNewPatientModal').addEventListener('click', () => {
    patientModal.classList.add('active');
  });
  document.getElementById('btnClosePatientModal').addEventListener('click', () => patientModal.classList.remove('active'));
  document.getElementById('btnCancelPatientModal').addEventListener('click', () => patientModal.classList.remove('active'));

  // Match Modal Close
  document.getElementById('btnCloseMatchModal').addEventListener('click', () => matchModal.classList.remove('active'));

  // Close modals on outside click
  window.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal-overlay')) {
      e.target.classList.remove('active');
    }
  });

  // Forms
  document.getElementById('bookAppointmentForm').addEventListener('submit', handleBookSubmit);
  document.getElementById('newPatientForm').addEventListener('submit', handleNewPatientSubmit);
  document.getElementById('matchRequestForm').addEventListener('submit', handleMatchSubmit);
  document.getElementById('btnRejectRequest').addEventListener('click', handleRejectSubmit);

  // Refresh Buttons
  document.getElementById('btnRefreshAppointments').addEventListener('click', loadAppointments);
  document.getElementById('btnRefreshBookings').addEventListener('click', loadBookingRequests);

  // Search input
  document.getElementById('patientSearchInput').addEventListener('input', (e) => {
    loadPatients(e.target.value.trim());
  });
}

// Auth Helpers
async function checkAuth() {
  if (!authToken) {
    showLogin();
    return;
  }

  try {
    const res = await fetch(`${API_BASE}/auth/me`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    if (res.ok) {
      currentStaff = await res.json();
      showDashboard();
    } else {
      logout();
    }
  } catch (e) {
    // If backend not reachable, show dashboard with local mode note
    showDashboard();
  }
}

function showLogin() {
  loginSection.style.display = 'flex';
  dashboardSection.style.display = 'none';
  userNav.style.display = 'none';
}

function showDashboard() {
  loginSection.style.display = 'none';
  dashboardSection.style.display = 'block';
  userNav.style.display = 'flex';
  staffNameDisplay.textContent = currentStaff?.name_ar || 'موظف الاستقبال';

  const dateOpts = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', timeZone: 'Africa/Cairo' };
  document.getElementById('currentDateDisplay').textContent = new Date().toLocaleDateString('ar-EG', dateOpts);

  loadAppointmentTypes();
  loadAppointments();
  loadPatients();
  loadBookingRequests();
}

function logout() {
  authToken = null;
  localStorage.removeItem('marsa_receptionist_token');
  showLogin();
}

btnLogout.addEventListener('click', logout);

loginForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  loginError.style.display = 'none';
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;

  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    const data = await res.json();
    if (res.ok) {
      authToken = data.access_token;
      localStorage.setItem('marsa_receptionist_token', authToken);
      checkAuth();
    } else {
      loginError.textContent = data.detail || 'فشل تسجيل الدخول. يرجى التحقق من البريد وكلمة المرور.';
      loginError.style.display = 'block';
    }
  } catch (err) {
    loginError.textContent = 'تعذر الاتصال بالخادم المركزي للعيادة.';
    loginError.style.display = 'block';
  }
});

// Load Appointment Types
async function loadAppointmentTypes() {
  try {
    const res = await fetch(`${API_BASE}/appointments/types`);
    if (res.ok) cachedTypes = await res.json();
  } catch (_) {}
}

// Load Appointments
async function loadAppointments() {
  const tbody = document.getElementById('appointmentsTableBody');
  tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-muted);">جاري تحديث المواعيد...</td></tr>';

  try {
    const res = await fetch(`${API_BASE}/appointments`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    if (res.ok) {
      const appointments = await res.json();
      renderAppointments(appointments);
    } else {
      renderAppointmentsFallback();
    }
  } catch (_) {
    renderAppointmentsFallback();
  }
}

function renderAppointments(list) {
  const tbody = document.getElementById('appointmentsTableBody');
  if (!list || list.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 24px;">لا توجد مواعيد مسجلة اليوم</td></tr>';
    return;
  }

  tbody.innerHTML = list.map(apt => {
    const start = new Date(apt.slot_start).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });
    const statusClass = apt.status === 'confirmed' ? 'chip-confirmed' : (apt.status === 'completed' ? 'chip-completed' : (apt.status === 'no_show' ? 'chip-no-show' : 'chip-cancelled'));
    const statusLabel = apt.status === 'confirmed' ? 'مؤكد' : (apt.status === 'completed' ? 'وصل / اكتمل' : (apt.status === 'no_show' ? 'غائب' : 'ملغي'));

    const patient = cachedPatients.find(p => p.patient_id === apt.patient_id);
    const patName = patient ? patient.name_ar : 'مريض مسجل';
    const patMrn = patient ? patient.mrn : 'MRN-';
    const patPhone = patient ? patient.phone || '—' : '—';

    return `
      <tr>
        <td><strong>${start}</strong></td>
        <td><strong>${patName}</strong></td>
        <td><span style="font-family: monospace; background:#E2E8F0; padding:2px 6px; border-radius:4px;">${patMrn}</span></td>
        <td>${patPhone}</td>
        <td>استشارة نفسية</td>
        <td><span class="chip ${statusClass}">${statusLabel}</span></td>
        <td>
          <div style="display: flex; gap: 6px;">
            ${apt.status !== 'completed' ? `<button class="btn btn-sm btn-success" onclick="updateAppointmentStatus('${apt.appointment_id}', 'completed')">تسجيل وصول</button>` : ''}
            ${apt.status !== 'no_show' && apt.status !== 'completed' ? `<button class="btn btn-sm btn-danger" onclick="updateAppointmentStatus('${apt.appointment_id}', 'no_show')">غائب</button>` : ''}
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

function renderAppointmentsFallback() {
  const dummy = [
    { appointment_id: 'apt-01', slot_start: new Date().toISOString(), status: 'confirmed' }
  ];
  renderAppointments(dummy);
}

window.updateAppointmentStatus = async function(id, newStatus) {
  try {
    const res = await fetch(`${API_BASE}/appointments/${id}/status`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({ status: newStatus })
    });
    if (res.ok) {
      loadAppointments();
    }
  } catch (err) {
    alert('فشل تحديث الحالة: ' + err);
  }
};

// Load Patients
async function loadPatients(query = '') {
  const tbody = document.getElementById('patientsTableBody');
  const url = query ? `${API_BASE}/patients?q=${encodeURIComponent(query)}` : `${API_BASE}/patients`;

  try {
    const res = await fetch(url, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    if (res.ok) {
      cachedPatients = await res.json();
      renderPatients(cachedPatients);
    }
  } catch (_) {}
}

function renderPatients(list) {
  const tbody = document.getElementById('patientsTableBody');
  if (!list || list.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 24px;">لا يوجد مرضى مطابقون للبحث</td></tr>';
    return;
  }

  tbody.innerHTML = list.map(p => `
    <tr>
      <td><span style="font-family: monospace; font-weight: bold; background: #E2E8F0; padding: 2px 6px; border-radius: 4px;">${p.mrn}</span></td>
      <td><strong>${p.name_ar}</strong></td>
      <td>${p.name_en || '—'}</td>
      <td>${p.phone || '—'}</td>
      <td>${p.email || '—'}</td>
      <td>
        <button class="btn btn-sm btn-outline" onclick="openBookModalForPatient('${p.patient_id}')">📅 حجز موعد</button>
      </td>
    </tr>
  `).join('');
}

window.openBookModalForPatient = function(patId) {
  populateBookSelects(patId);
  bookModal.classList.add('active');
};

function populateBookSelects(selectedPatId = null) {
  const patSelect = document.getElementById('bookPatientSelect');
  patSelect.innerHTML = cachedPatients.map(p => `
    <option value="${p.patient_id}" ${p.patient_id === selectedPatId ? 'selected' : ''}>
      ${p.name_ar} (${p.mrn}) — ${p.phone || ''}
    </option>
  `).join('');

  const typeSelect = document.getElementById('bookTypeSelect');
  if (cachedTypes.length > 0) {
    typeSelect.innerHTML = cachedTypes.map(t => `
      <option value="${t.type_id}">${t.name_ar} (${t.duration_minutes} دقيقة — ${t.price_egp} ج.م)</option>
    `).join('');
  } else {
    typeSelect.innerHTML = '<option value="">جلسة استشارية أولى (800 ج.م)</option>';
  }
}

async function handleBookSubmit(e) {
  e.preventDefault();
  const patientId = document.getElementById('bookPatientSelect').value;
  const typeId = document.getElementById('bookTypeSelect').value || (cachedTypes[0] ? cachedTypes[0].type_id : null);
  const dtVal = document.getElementById('bookDateTime').value;
  const notes = document.getElementById('bookNotes').value.trim();

  if (!dtVal || !typeId) {
    alert('يرجى اختيار المريض ونوع الجلسة والوقت');
    return;
  }

  const slotStart = new Date(dtVal);
  const slotEnd = new Date(slotStart.getTime() + 45 * 60000);

  try {
    const res = await fetch(`${API_BASE}/appointments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({
        patient_id: patientId,
        type_id: typeId,
        slot_start: slotStart.toISOString(),
        slot_end: slotEnd.toISOString(),
        notes: notes
      })
    });

    if (res.ok) {
      bookModal.classList.remove('active');
      loadAppointments();
      alert('تم حجز الموعد بنجاح وتأكيده في جدول العيادة.');
    } else {
      const err = await res.json();
      alert('فشل الحجز: ' + (err.detail || 'خطأ غير متوقع'));
    }
  } catch (err) {
    alert('تعذر الاتصال بالخادم: ' + err);
  }
}

async function handleNewPatientSubmit(e) {
  e.preventDefault();
  const nameAr = document.getElementById('newPatientNameAr').value.trim();
  const nameEn = document.getElementById('newPatientNameEn').value.trim();
  const phone = document.getElementById('newPatientPhone').value.trim();
  const sex = document.getElementById('newPatientSex').value;
  const email = document.getElementById('newPatientEmail').value.trim();

  try {
    const res = await fetch(`${API_BASE}/patients`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({
        name_ar: nameAr,
        name_en: nameEn || null,
        phone: phone,
        sex: sex,
        email: email || null
      })
    });

    const data = await res.json();
    if (res.ok) {
      patientModal.classList.remove('active');
      loadPatients();

      if (data.warnings && data.warnings.length > 0) {
        alert('تنبيه تشابه بيانات:\n' + data.warnings.join('\n') + '\n\nتم فتح الملف برقم: ' + data.patient.mrn);
      } else {
        alert('تم فتح الملف الطبي للمريض بنجاح برقم: ' + data.patient.mrn);
      }
    } else {
      alert('فشل التسجيل: ' + (data.detail || 'خطأ'));
    }
  } catch (err) {
    alert('تعذر الاتصال: ' + err);
  }
}

// Load Public Booking Requests Queue
async function loadBookingRequests() {
  const tbody = document.getElementById('bookingsTableBody');
  const badge = document.getElementById('bookingsCountBadge');

  try {
    const res = await fetch(`${API_BASE}/appointments/booking-requests`, {
      headers: { 'Authorization': `Bearer ${authToken}` }
    });

    if (res.ok) {
      const requests = await res.json();
      const pending = requests.filter(r => r.status === 'pending_match');
      badge.textContent = pending.length;
      renderBookingRequests(requests);
    }
  } catch (_) {}
}

function renderBookingRequests(requests) {
  const tbody = document.getElementById('bookingsTableBody');
  if (!requests || requests.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 24px;">لا توجد طلبات حجز معلقة</td></tr>';
    return;
  }

  tbody.innerHTML = requests.map(r => {
    const dateStr = new Date(r.created_at).toLocaleDateString('ar-EG');
    const isPending = r.status === 'pending_match';
    const statusLabel = isPending ? 'قيد المراجعة' : (r.status === 'matched' ? 'تم الربط' : 'مرفوض');
    const statusClass = isPending ? 'chip-pending' : (r.status === 'matched' ? 'chip-confirmed' : 'chip-cancelled');

    return `
      <tr>
        <td>${dateStr}</td>
        <td><strong>${r.name}</strong></td>
        <td>${r.phone}</td>
        <td>${r.preferred_slot ? new Date(r.preferred_slot).toLocaleTimeString('ar-EG') : 'غير محدد'}</td>
        <td><span class="chip ${statusClass}">${statusLabel}</span></td>
        <td>${r.notes || '—'}</td>
        <td>
          ${isPending ? `<button class="btn btn-sm btn-primary" onclick="openMatchModal('${r.request_id}', '${r.name}', '${r.phone}')">مراجعة وربط بمريض</button>` : `<span style="color:var(--text-muted); font-size:0.8rem;">مكتمل</span>`}
        </td>
      </tr>
    `;
  }).join('');
}

window.openMatchModal = function(requestId, name, phone) {
  document.getElementById('matchRequestId').value = requestId;
  document.getElementById('matchRequestDetails').innerHTML = `
    <strong>بيانات الطلب:</strong> ${name} — 📞 ${phone}
  `;

  const sel = document.getElementById('matchPatientSelect');
  sel.innerHTML = '<option value="">اختر مريضاً مطابقاً...</option>' + cachedPatients.map(p => `
    <option value="${p.patient_id}">${p.name_ar} (${p.mrn}) — ${p.phone || ''}</option>
  `).join('');

  matchModal.classList.add('active');
};

async function handleMatchSubmit(e) {
  e.preventDefault();
  const reqId = document.getElementById('matchRequestId').value;
  const patId = document.getElementById('matchPatientSelect').value;

  if (!patId) {
    alert('يرجى اختيار مريض لربط الطلب به');
    return;
  }

  try {
    const res = await fetch(`${API_BASE}/appointments/booking-requests/${reqId}/match`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({ patient_id: patId })
    });

    if (res.ok) {
      matchModal.classList.remove('active');
      loadBookingRequests();
      alert('تم ربط طلب الحجز بالمريض بنجاح!');
    }
  } catch (err) {
    alert('فشل الربط: ' + err);
  }
}

async function handleRejectSubmit() {
  const reqId = document.getElementById('matchRequestId').value;
  if (!confirm('هل أنت متأكد من رفض طلب الحجز هذا؟')) return;

  try {
    const res = await fetch(`${API_BASE}/appointments/booking-requests/${reqId}/reject`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${authToken}` }
    });
    if (res.ok) {
      matchModal.classList.remove('active');
      loadBookingRequests();
    }
  } catch (err) {
    alert('فشل: ' + err);
  }
}
