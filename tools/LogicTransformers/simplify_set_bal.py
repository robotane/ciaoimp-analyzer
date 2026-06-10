import glob, re

for f in glob.glob("0_source/*.pl"):
    with open(f, "r") as file:
        content = file.read()
    
    # We want to replace the `Found := 0` logic and `if (Found == 0) ...` in set_bal.
    # The set_bal definition usually looks like:
    """
set_bal(Addr, NewVal, !B) :-
    Found := 0,
    Acc := [],
    for (Entry in list(B)) {
        Entry = bal(A, V),
        if (A == Addr) {
            Acc := [bal(Addr, NewVal) | Acc],
            Found := 1
        } else {
            Acc := [bal(A, V) | Acc]
        }
    },
    if (Found == 0) { Acc := [bal(Addr, NewVal) | Acc] },
    B := Acc.
    """
    
    new_set_bal = """set_bal(Addr, NewVal, !B) :-
    Acc := [],
    for (Entry in list(B)) {
        Entry = bal(A, V),
        if (A == Addr) {
            Acc := [bal(Addr, NewVal) | Acc]
        } else {
            Acc := [bal(A, V) | Acc]
        }
    },
    B := Acc."""

    content = re.sub(
        r"set_bal\(Addr, NewVal, !B\) :-\s+Found := 0,\s+Acc := \[\],\s+for \(Entry in list\(B\)\) \{\s+Entry = bal\(A, V\),\s+if \(A == Addr\) \{\s+Acc := \[bal\(Addr, NewVal\) \| Acc\],\s+Found := 1\s+\}\s+else\s+\{\s+Acc := \[bal\(A, V\) \| Acc\]\s+\}\s+\},\s+if \(Found == 0\) \{ Acc := \[bal\(Addr, NewVal\) \| Acc\] \},\s+B := Acc\.",
        new_set_bal,
        content,
        flags=re.MULTILINE
    )
    
    with open(f, "w") as file:
        file.write(content)
