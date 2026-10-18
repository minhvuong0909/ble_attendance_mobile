import pytest

from app.core.validators import is_valid_student_id, normalize_id


@pytest.mark.parametrize("value", ["25CE099", "D26CE045", "24SE001", "25ABC123"])
def test_valid_student_ids(value):
    assert is_valid_student_id(value)


@pytest.mark.parametrize("value", ["", "25ce099", "T001", "2CE099", "25CE99", "D26C045"])
def test_invalid_student_ids(value):
    assert not is_valid_student_id(value)


def test_normalize_id_strips_and_uppercases():
    assert normalize_id("  25ce099 ") == "25CE099"
