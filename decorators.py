from __future__ import annotations

import dataclasses
import types
from datetime import date, datetime, time
from decimal import Decimal
from enum import Enum
from typing import Any, TypeVar, Union, get_args, get_origin, get_type_hints

T = TypeVar("T")


def _is_union(origin: Any) -> bool:
    return origin is Union or origin is getattr(types, "UnionType", None)  # X | Y


# ---------- to_dict ----------

def _to_dict(obj: Any) -> Any:
    if dataclasses.is_dataclass(obj) and not isinstance(obj, type):
        return {f.name: _to_dict(getattr(obj, f.name))
                for f in dataclasses.fields(obj)}
    if isinstance(obj, dict):
        return {_to_dict(k): _to_dict(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple, set, frozenset)):
        return [_to_dict(v) for v in obj]
    if isinstance(obj, Enum):
        return obj.value
    if isinstance(obj, (datetime, date, time)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return str(obj)  # lossless round-trip
    return obj


# ---------- from_dict (driven by type hints) ----------

def _from_dict(tp: Any, value: Any) -> Any:
    if value is None or tp is Any or tp is None:
        return value

    origin = get_origin(tp)
    args = get_args(tp)

    if _is_union(origin):  # Optional / Union / X | Y
        for candidate in (a for a in args if a is not type(None)):
            try:
                return _from_dict(candidate, value)
            except (TypeError, ValueError, KeyError):
                continue
        return value

    if dataclasses.is_dataclass(tp) and isinstance(tp, type):
        hints = get_type_hints(tp)  # resolves forward refs / `from __future__`
        names = {f.name for f in dataclasses.fields(tp)}
        return tp(**{k: _from_dict(hints.get(k, Any), v)
                     for k, v in value.items() if k in names})

    if origin in (list, set, frozenset):
        (elem_t,) = args or (Any,)
        return origin(_from_dict(elem_t, v) for v in value)
    if origin is tuple:
        if len(args) == 2 and args[1] is Ellipsis:        # tuple[X, ...]
            return tuple(_from_dict(args[0], v) for v in value)
        if args:                                          # tuple[X, Y, Z]
            return tuple(_from_dict(a, v) for a, v in zip(args, value))
        return tuple(value)
    if origin is dict:
        key_t, val_t = args or (Any, Any)
        return {_from_dict(key_t, k): _from_dict(val_t, v)
                for k, v in value.items()}

    if isinstance(tp, type):
        if issubclass(tp, Enum):
            return tp(value)
        if issubclass(tp, datetime):
            return datetime.fromisoformat(value)
        if issubclass(tp, date):  # datetime already handled above
            return date.fromisoformat(value)
        if issubclass(tp, time):
            return time.fromisoformat(value)
        if issubclass(tp, Decimal):
            return Decimal(value)

    return value


# ---------- decorator ----------

def dict_serializable(cls: type[T]) -> type[T]:
    def to_dict(self) -> dict[str, Any]:
        return _to_dict(self)

    @classmethod
    def from_dict(cls_: type[T], data: dict[str, Any]) -> T:
        return _from_dict(cls_, data)

    cls.to_dict = to_dict        # type: ignore[attr-defined]
    cls.from_dict = from_dict    # type: ignore[attr-defined]
    return cls