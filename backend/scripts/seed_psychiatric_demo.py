import asyncio
import uuid
from datetime import date, datetime, timezone
from sqlalchemy import select

from app.database import async_session_maker
from app.models.clinical import (
    Diagnosis,
    DiagnosisStatus,
    Medication,
    PatientClinical,
    PatientFile,
    PatientNote,
    Session,
    SessionStatus,
)
from app.models.patient import Patient
from app.models.staff import Staff, StaffRole
from app.utils.encryption import encrypt_field


async def seed_psychiatric_demo():
    print("Seeding rich psychiatric clinical demo data...")
    async with async_session_maker() as session:
        # Get doctor
        doc_res = await session.execute(
            select(Staff).where(Staff.role == StaffRole.doctor)
        )
        doctor = doc_res.scalars().first()
        if not doctor:
            print("Doctor staff not found!")
            return

        # Get patients
        pat_res = await session.execute(select(Patient).order_by(Patient.mrn))
        patients = pat_res.scalars().all()
        if not patients:
            print("No patients found!")
            return

        print(f"Found {len(patients)} patients to enrich with psychiatric data.")

        # Patient 1: أحمد محمود السعيد (MRN-00001)
        # 32 yo, Software Engineer, Married with 2 children
        p1 = patients[0]
        p1.dob = date(1992, 5, 14)
        p1.occupation = "مهندس برمجيات"
        p1.marital_status = "متزوج"
        p1.children = "ولد وبنت (6 و 3 سنوات)"
        p1.address = "مدينة نصر، القاهرة"
        p1.first_session_date = date(2026, 1, 15)
        p1.last_session_date = date(2026, 10, 10)

        # Patient 1 Clinical
        c1 = await session.get(PatientClinical, p1.patient_id)
        if not c1:
            c1 = PatientClinical(patient_id=p1.patient_id, updated_by=doctor.staff_id)
            session.add(c1)

        c1.history = encrypt_field(
            "المريض يعاني من نوبات هلع متكررة بدأت منذ 8 أشهر مصحوبة بتسارع ضربات القلب وضيق تنفس وخوف شديد من الموت أو فقدان السيطرة، خاصة أثناء ضغوط العمل وركوب المترو."
        )
        c1.psychiatric_examinations = encrypt_field(
            "المظهر مهندم ومناسب، متوتر وحركي أثناء الجلسة. التواصل البصري جيد، الكلام متدفق بمعدل طبيعي. المزاج قلق، الوجدان متطابق. لا توجد هلاوس أو ضلالات. الاستبصار جيد ومدرك لحالته."
        )
        c1.physical_neurological_exam = encrypt_field(
            "فحص عصبي سليم، منعكسات الأوتار متناظرة، لا توجد علامات عصبية بؤرية. ضغط الدم 125/80، النبض 84/دقيقة، رسم القلب ECG سليم."
        )
        c1.risk_assessment = encrypt_field(
            "مستوى خطورة منخفض، لا توجد ميول إيذاء للنفس أو الغير. يوجد قلق توقعي ملحوظ."
        )
        c1.suicide_attempts = encrypt_field("لا توجد أي محاولات انتحار سابقة.")
        c1.admitted_before = encrypt_field("لم يسبق له الدخول لأي مصحة أو مستشفى نفسي.")
        c1.medical_history = encrypt_field("حساسية موسمية خفيفة، لا يعاني من ضغط أو سكر.")
        c1.family_history = encrypt_field("الوالدة تعاني من اضطراب قلق معمم.")
        c1.social_history = encrypt_field("غير مدخن، لا يتعاطى أي مواد مخدرة أو كحوليات، علاقاته الأسرية مستقرة وداعمة.")
        c1.allergies = ["البنسلين"]
        c1.notes = encrypt_field("مستجيب جيداً لجلسات CBT مع تقنيات التنفس البطائي وإعادة الهيكلة المعرفية.")

        # Patient 1 Diagnoses
        d1 = Diagnosis(
            diagnosis_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            icd10_code="F41.0",
            description_ar="اضطراب الهلع (Panic Disorder)",
            description_en="Panic Disorder",
            date_diagnosed=date(2026, 1, 15),
            status=DiagnosisStatus.active,
            author_id=doctor.staff_id,
        )
        session.add(d1)

        # Patient 1 Medications
        m1 = Medication(
            medication_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            name_ar="سبرالكس (إسيتالوبرام)",
            name_en="Cipralex (Escitalopram)",
            dose="10 mg",
            frequency="مرة واحدة صباحاً بعد الإفطار",
            duration="6 أشهر",
            date=date(2026, 1, 20),
            route="فموي",
            notes="متابعة أي أعراض هضمية في أول أسبوعين",
            prescribed_by=doctor.staff_id,
            is_active=True,
        )
        m2 = Medication(
            medication_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            name_ar="إندرال (بروبرانولول)",
            name_en="Inderal (Propranolol)",
            dose="10 mg",
            frequency="عند اللزوم قبل المواقف المسببة للتوتر بنصف ساعة",
            duration="عند الحاجة",
            date=date(2026, 1, 20),
            route="فموي",
            notes="لتخفيف الأعراض الجسدية لنوبة الهلع وتسارع النبض",
            prescribed_by=doctor.staff_id,
            is_active=True,
        )
        session.add_all([m1, m2])

        # Patient 1 Files
        f1 = PatientFile(
            file_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            file_name="تقرير رسم القلب والتحاليل الشاملة.pdf",
            file_type="medical_report",
            file_location="/uploads/reports/ecg_lab_ahmed.pdf",
        )
        session.add(f1)

        # Patient 1 Quick Notes
        n1 = PatientNote(
            note_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            note_text="تحسن واضح في نوبات الهلع بنسبة 70% بعد 8 جلسات، لم تحدث أي نوبة كاملة خلال آخر أسبوعين.",
        )
        n2 = PatientNote(
            note_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            note_text="يرغب في مناقشة تخفيض الجرعة الدوائية تدريجياً في المتابعة القادمة بعد شهرين.",
        )
        session.add_all([n1, n2])

        # Patient 1 Session
        s1 = Session(
            session_id=uuid.uuid4(),
            patient_id=p1.patient_id,
            started_at=datetime(2026, 10, 10, 14, 0, tzinfo=timezone.utc),
            ended_at=datetime(2026, 10, 10, 14, 45, tzinfo=timezone.utc),
            status=SessionStatus.finalized,
            session_number=6,
            chief_complaint="متابعة دورية ومناقشة تحديات بيئة العمل الجديدة",
            sleep="منتظم (7 ساعات ليلاً، بدون استيقاظ متكرر)",
            appetite="جيدة ومستقرة",
            mood="مستقر وهادئ، قلق طفيف مع مواعيد التسليم",
            anxiety="منخفض إلى متوسط (GAD-7 score: 4)",
            suicidal_self_harm_assessment="لا توجد أي أفكار سلبية أو ميول إيذاء",
            substance_use="لا يوجد",
            mental_status_examination="مظهر مرتب، تفاعل إيجابي، تركيز جيد، استبصار تام بالحالة والتطور العلاجي",
            diagnosis="F41.0 - اضطراب الهلع في حالة تحسن مستقر",
            treatment_plan="الاستمرار على Cipralex 10mg ومتابعة تمارين التعرض التدريجي وملاحظة الأفكار التلقائية",
            follow_up="جلسة متابعة بعد 4 أسابيع",
            created_by=doctor.staff_id,
            finalized_by=doctor.staff_id,
            finalized_at=datetime(2026, 10, 10, 15, 0, tzinfo=timezone.utc),
        )
        session.add(s1)

        # Patient 2: مريم عادل الشناوي (MRN-00002)
        if len(patients) > 1:
            p2 = patients[1]
            p2.dob = date(1998, 8, 22)
            p2.occupation = "باحثة ماجستير"
            p2.marital_status = "عزباء"
            p2.children = "لا يوجد"
            p2.address = "المعادي، القاهرة"
            p2.first_session_date = date(2026, 3, 5)
            p2.last_session_date = date(2026, 9, 28)

            c2 = await session.get(PatientClinical, p2.patient_id)
            if not c2:
                c2 = PatientClinical(patient_id=p2.patient_id, updated_by=doctor.staff_id)
                session.add(c2)

            c2.history = encrypt_field(
                "أفكار وسواسية حول التلوث والنظافة مصحوبة بأفعال قهرية متكررة كغسل الأيدي والتحقق المتكرر من إغلاق الأبواب والأجهزة، مما يستهلك 3-4 ساعات يومياً."
            )
            c2.psychiatric_examinations = encrypt_field(
                "متوترة، جلد اليدين متقشر ومحمر نتيجة الغسيل المتكرر. الوعي والاستبصار تام بأن الأفكار مبالغ فيها لكنها تشعر بضيق شديد عند مقاومتها."
            )
            c2.physical_neurological_exam = encrypt_field("فحص عصبي طبيعي، التهاب جلدي خفيف باليدين نتيجة المنظفات.")
            c2.risk_assessment = encrypt_field("لا يوجد خطر انتحاري، انزعاج وإرهاق نفسي ملحوظ.")
            c2.suicide_attempts = encrypt_field("لا يوجد")
            c2.admitted_before = encrypt_field("لا يوجد")
            c2.medical_history = encrypt_field("لا توجد أمراض مزمنة")
            c2.family_history = encrypt_field("الخالة تعاني من وسواس قهري مشابه")
            c2.allergies = ["السلفا"]

            d2 = Diagnosis(
                diagnosis_id=uuid.uuid4(),
                patient_id=p2.patient_id,
                icd10_code="F42",
                description_ar="اضطراب الوسواس القهري (OCD)",
                description_en="Obsessive-Compulsive Disorder",
                date_diagnosed=date(2026, 3, 5),
                status=DiagnosisStatus.active,
                author_id=doctor.staff_id,
            )
            m3 = Medication(
                medication_id=uuid.uuid4(),
                patient_id=p2.patient_id,
                name_ar="فافيرين (فلوفوكسامين)",
                name_en="Faverin (Fluvoxamine)",
                dose="100 mg",
                frequency="قرص مساءً قبل النوم",
                duration="4 أشهر",
                date=date(2026, 3, 10),
                route="فموي",
                notes="زيادة تدريجية حسب الاستجابة السريرية",
                prescribed_by=doctor.staff_id,
                is_active=True,
            )
            session.add_all([d2, m3])

        await session.commit()
        print("Psychiatric demo data successfully seeded!")


if __name__ == "__main__":
    asyncio.run(seed_psychiatric_demo())
