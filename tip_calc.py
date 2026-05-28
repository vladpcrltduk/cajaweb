import sys


def calculate_tip(bill: float, tip_percent: float) -> tuple[float, float]:
    tip = round(bill * tip_percent / 100, 2)
    total = round(bill + tip, 2)
    return tip, total


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python tip_calc.py <bill> <tip_percent>")
        sys.exit(1)

    bill = float(sys.argv[1])
    tip_percent = float(sys.argv[2])
    tip, total = calculate_tip(bill, tip_percent)

    print(f"Tip:   ${tip:.2f}")
    print(f"Total: ${total:.2f}")
