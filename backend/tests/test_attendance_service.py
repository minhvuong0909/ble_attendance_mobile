from datetime import date, datetime, timedelta

import pytest
from sqlalchemy import select

from app.models import (
    Attendance,
    AttendanceStatus,
    Detection,
    LeaveRequest,
    LeaveStatus,
    LectureSession,
    UserRole,
)
from app.services.attendance import finalize_session, resolve_status

START = datetime(2026, 10, 18, 3, 0, 0)  # 10:00 giờ địa phương


@pytest.fixture()
def world(make_user, make_class, enroll):
    teacher = make_user(UserRole.teacher, "T001")
    student = make_user(UserRole.student, "25CE099")
    cls = make_class(teacher=teacher)
    enroll(cls, student)
    return teacher, student, cls


def ended_session(db, cls, teacher, starts=START, seconds=300):
    session = LectureSession(
        class_id=cls.id,
        teacher_user_id=teacher.id,
        token="abcdef0123456789",
        starts_at=starts,
        ends_at=starts + timedelta(seconds=seconds),
        is_active=False,
    )
    db.add(session)
    db.commit()
    return session


def detect(db, session, student, windows, rssi=-60):
    for window in windows:
        db.add(
            Detection(
                session_id=session.id,
                student_user_id=student.id,
                rssi=rssi,
                detected_at=session.starts_at + timedelta(seconds=window * 30 + 1),
            )
        )
    db.commit()


def finalize_row(db, session, student):
    db.add(Attendance(session_id=session.id, student_user_id=student.id, finalized=True))
    db.commit()


def row_of(db, session, student):
    return db.scalar(
        select(Attendance).where(
            Attendance.session_id == session.id, Attendance.student_user_id == student.id
        )
    )


@pytest.mark.parametrize(
    "ratio,finalized,excused,expected",
    [
        (0.6, True, False, AttendanceStatus.present),
        (0.59, True, False, AttendanceStatus.absent),
        (1.0, False, False, AttendanceStatus.absent),
        (0.0, False, True, AttendanceStatus.excused),
        (1.0, False, True, AttendanceStatus.excused),
        (1.0, True, True, AttendanceStatus.present),
    ],
)
def test_resolve_status(ratio, finalized, excused, expected):
    assert resolve_status(ratio, finalized, excused) == expected


def test_present_needs_ratio_and_finalization(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, range(6))  # 6/10 = 0.6
    finalize_row(db, session, student)
    finalize_session(db, session)
    db.commit()
    row = row_of(db, session, student)
    assert row.presence_ratio == 0.6
    assert row.status == AttendanceStatus.present


def test_not_finalized_is_absent_even_with_full_presence(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, range(10))
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_finalized_but_rarely_seen_is_absent(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, range(5))  # 0.5
    finalize_row(db, session, student)
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_student_never_seen_still_gets_absent_row(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    finalize_session(db, session)
    db.commit()
    row = row_of(db, session, student)
    assert row.status == AttendanceStatus.absent
    assert row.presence_ratio == 0.0
    assert row.first_seen_at is None


def test_first_seen_is_recorded(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    detect(db, session, student, [2, 3])
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).first_seen_at == START + timedelta(seconds=61)


def test_approved_leave_makes_absence_excused(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    db.add(
        LeaveRequest(
            student_user_id=student.id,
            class_id=cls.id,
            date=date(2026, 10, 18),
            reason="Ốm",
            status=LeaveStatus.approved,
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.excused


def test_pending_or_rejected_leave_does_not_excuse(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    for status in (LeaveStatus.pending, LeaveStatus.rejected):
        db.add(
            LeaveRequest(
                student_user_id=student.id,
                class_id=cls.id,
                date=date(2026, 10, 18),
                reason="Ốm",
                status=status,
            )
        )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_leave_date_uses_local_calendar_day(db, world):
    teacher, student, cls = world
    # 23:30 UTC ngày 17 = 06:30 giờ địa phương ngày 18.
    session = ended_session(db, cls, teacher, starts=datetime(2026, 10, 17, 23, 30, 0))
    db.add(
        LeaveRequest(
            student_user_id=student.id,
            class_id=cls.id,
            date=date(2026, 10, 18),
            reason="Ốm",
            status=LeaveStatus.approved,
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.excused


def test_leave_for_another_class_does_not_excuse(db, world, make_class):
    teacher, student, cls = world
    other = make_class(teacher=teacher, class_code="SE1902")
    session = ended_session(db, cls, teacher)
    db.add(
        LeaveRequest(
            student_user_id=student.id,
            class_id=other.id,
            date=date(2026, 10, 18),
            reason="Ốm",
            status=LeaveStatus.approved,
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    assert row_of(db, session, student).status == AttendanceStatus.absent


def test_override_survives_finalize_session(db, world):
    teacher, student, cls = world
    session = ended_session(db, cls, teacher)
    db.add(
        Attendance(
            session_id=session.id,
            student_user_id=student.id,
            status=AttendanceStatus.present,
            overridden_by=teacher.id,
            override_reason="GV xác nhận",
        )
    )
    db.commit()
    finalize_session(db, session)
    db.commit()
    row = row_of(db, session, student)
    assert row.status == AttendanceStatus.present
    assert row.presence_ratio == 0.0


def test_finalize_session_only_creates_rows_for_enrolled_students(db, world, make_user):
    teacher, student, cls = world
    make_user(UserRole.student, "25CE100")
    session = ended_session(db, cls, teacher)
    finalize_session(db, session)
    db.commit()
    assert len(list(db.scalars(select(Attendance)))) == 1
