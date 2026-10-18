import pytest
from sqlalchemy.exc import IntegrityError

from app.models import (
    Attendance,
    ClassRoom,
    Course,
    Enrollment,
    User,
    UserRole,
)


def _user(db, role, **ids):
    user = User(full_name="X", role=role, password_hash="h", **ids)
    db.add(user)
    db.commit()
    return user


def test_login_id_returns_student_or_teacher_id(db):
    student = _user(db, UserRole.student, student_id="25CE099")
    teacher = _user(db, UserRole.teacher, teacher_id="T001")
    assert student.login_id == "25CE099"
    assert teacher.login_id == "T001"


def test_new_user_does_not_need_password_change(db):
    user = _user(db, UserRole.student, student_id="25CE099")
    assert user.must_change_password is False


def test_class_is_unique_per_course_code_semester(db):
    course = Course(code="PRM393", name="Mobile")
    db.add(course)
    db.commit()
    db.add(ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA"))
    db.commit()
    db.add(ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="BBBBBB"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_class_defaults(db):
    course = Course(code="PRM393", name="Mobile")
    db.add(course)
    db.commit()
    cls = ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA")
    db.add(cls)
    db.commit()
    assert cls.max_absence_percent == 20
    assert cls.rssi_threshold == -75
    assert cls.teacher_user_id is None


def test_enrollment_is_unique_per_class_and_student(db):
    course = Course(code="PRM393", name="Mobile")
    student = _user(db, UserRole.student, student_id="25CE099")
    db.add(course)
    db.commit()
    cls = ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA")
    db.add(cls)
    db.commit()
    db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="import"))
    db.commit()
    db.add(Enrollment(class_id=cls.id, student_user_id=student.id, source="join_code"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_attendance_is_unique_per_session_and_student(db):
    from app.models import LectureSession

    teacher = _user(db, UserRole.teacher, teacher_id="T001")
    student = _user(db, UserRole.student, student_id="25CE099")
    course = Course(code="PRM393", name="Mobile")
    db.add(course)
    db.commit()
    cls = ClassRoom(course_id=course.id, class_code="SE1901", semester="FA26", join_code="AAAAAA")
    db.add(cls)
    db.commit()
    session = LectureSession(class_id=cls.id, teacher_user_id=teacher.id, token="t" * 16)
    db.add(session)
    db.commit()
    db.add(Attendance(session_id=session.id, student_user_id=student.id))
    db.commit()
    db.add(Attendance(session_id=session.id, student_user_id=student.id))
    with pytest.raises(IntegrityError):
        db.commit()
