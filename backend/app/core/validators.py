import re

STUDENT_ID_PATTERN = re.compile(r"^(?:\d{2}[A-Z]{2,3}\d{3}|D\d{2}[A-Z]{2,3}\d{3})$")


def normalize_id(value: str) -> str:
    return value.strip().upper()


def is_valid_student_id(value: str) -> bool:
    return STUDENT_ID_PATTERN.match(value) is not None
