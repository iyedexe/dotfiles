# python-utils

Small standalone Python helpers. No dependencies beyond the standard library.

## decorators.py

`@dict_serializable` adds `to_dict()` and `from_dict()` to a dataclass.

```python
from dataclasses import dataclass
from datetime import date
from decorators import dict_serializable

@dict_serializable
@dataclass
class Item:
    name: str
    when: date
    tags: list[str]

d = Item("a", date(2026, 1, 2), ["x"]).to_dict()
# {'name': 'a', 'when': '2026-01-02', 'tags': ['x']}
assert Item.from_dict(d) == Item("a", date(2026, 1, 2), ["x"])
```

- `to_dict` converts nested dataclasses, dicts, lists, tuples and sets, enums
  to their value, dates and times to ISO strings, and `Decimal` to a string so
  it round-trips without loss.
- `from_dict` is driven by the type hints, so it rebuilds nested dataclasses,
  `Optional`/`X | None`, containers, enums, dates and decimals from that
  output.

Copy the file into a project, or put this folder on `PYTHONPATH`.
