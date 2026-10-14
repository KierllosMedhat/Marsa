import asyncio
from datetime import datetime, timedelta, timezone
import uuid
from app.database import Base, engine, async_session_maker
from app.models.staff import Staff, StaffRole
from app.models.appointment import Appointment, AppointmentStatus, AppointmentType
from app.models.patient import Patient, PatientSex
from app.models.booking import BookingRequest, BookingStatus
from app.services.auth_service import auth_service

async def seed():
    print("Creating tables in local database...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("Tables created successfully.")

    async with async_session_maker() as session:
        # 1. Staff Accounts
        doc_pwd = auth_service.hash_password("DoctorPass123!")
        rec_pwd = auth_service.hash_password("ReceptionPass123!")

        doctor = Staff(
            staff_id=uuid.uuid4(),
            role=StaffRole.doctor,
            name_ar="د. مارينا نبيه نمر",
            name_en="Dr. Marina Nabih Nemer",
            email="doctor@marsa.clinic",
            phone="01000000001",
            password_hash=doc_pwd,
            mfa_enabled=False,
            is_active=True,
        )

        receptionist = Staff(
            staff_id=uuid.uuid4(),
            role=StaffRole.receptionist,
            name_ar="سارة مصطفى (الاستقبال)",
            name_en="Sara Mostafa (Receptionist)",
            email="receptionist@marsa.clinic",
            phone="01000000002",
            password_hash=rec_pwd,
            mfa_enabled=False,
            is_active=True,
        )

        session.add_all([doctor, receptionist])
        await session.flush()

        # 2. Appointment Types
        type_eval = AppointmentType(
            type_id=uuid.uuid4(),
            name_ar="كشف وتقييم نفسي أولي",
            name_en="Initial Psychiatric Evaluation",
            duration_minutes=60,
            price_egp=800.0,
            is_active=True,
        )
        type_cbt = AppointmentType(
            type_id=uuid.uuid4(),
            name_ar="جلسة علاج معرفي سلوكي (CBT)",
            name_en="Cognitive Behavioral Therapy (CBT)",
            duration_minutes=45,
            price_egp=600.0,
            is_active=True,
        )
        type_med = AppointmentType(
            type_id=uuid.uuid4(),
            name_ar="متابعة استشارية وتقييم دوائي",
            name_en="Medication Follow-up",
            duration_minutes=30,
            price_egp=500.0,
            is_active=True,
        )
        session.add_all([type_eval, type_cbt, type_med])
        await session.flush()

        # 3. Demo Patients
        pat1 = Patient(
            patient_id=uuid.uuid4(),
            mrn="MRN-00001",
            name_ar="أحمد محمود السعيد",
            name_en="Ahmed Mahmoud El-Saeed",
            phone="01012345678",
            email="ahmed.m@example.com",
            sex=PatientSex.male,
            created_by=doctor.staff_id,
        )
        pat2 = Patient(
            patient_id=uuid.uuid4(),
            mrn="MRN-00002",
            name_ar="مريم عادل الشناوي",
            name_en="Mariam Adel El-Shennawy",
            phone="01123456789",
            email="mariam.a@example.com",
            sex=PatientSex.female,
            created_by=doctor.staff_id,
        )
        pat3 = Patient(
            patient_id=uuid.uuid4(),
            mrn="MRN-00003",
            name_ar="طارق حسام الدين",
            name_en="Tarek Hossam",
            phone="01234567890",
            sex=PatientSex.male,
            created_by=doctor.staff_id,
        )
        session.add_all([pat1, pat2, pat3])
        await session.flush()

        # 4. Today Appointments
        now = datetime.now(timezone.utc)
        appt1 = Appointment(
            appointment_id=uuid.uuid4(),
            patient_id=pat1.patient_id,
            type_id=type_eval.type_id,
            slot_start=now.replace(hour=8, minute=0, second=0),
            slot_end=now.replace(hour=9, minute=0, second=0),
            status=AppointmentStatus.confirmed,
            notes="شكوى من نوبات هلع وقلق عام في بيئة العمل",
        )
        appt2 = Appointment(
            appointment_id=uuid.uuid4(),
            patient_id=pat2.patient_id,
            type_id=type_cbt.type_id,
            slot_start=now.replace(hour=9, minute=30, second=0),
            slot_end=now.replace(hour=10, minute=15, second=0),
            status=AppointmentStatus.confirmed,
            notes="جلسة متابعة أسبوعية للتعرض ومنع الاستجابة (ERP)",
        )
        session.add_all([appt1, appt2])

        # 5. Public Booking Request
        req = BookingRequest(
            request_id=uuid.uuid4(),
            name="كريم عبد العزيز حامد",
            phone="01055667788",
            email="karim.h@example.com",
            type_id=type_eval.type_id,
            status=BookingStatus.pending_match,
            notes="أعاني من أرق مزمن منذ شهرين وصعوبة في التركيز",
        )
        session.add(req)

        await session.commit()
        print("Database seeded with Staff, Appointment Types, Patients, and Bookings successfully!")

if __name__ == "__main__":
    asyncio.run(seed())
