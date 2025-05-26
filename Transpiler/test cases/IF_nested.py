def main():
    x = 1
    y = 2
    z = 3
    b = True
    q = 1.1
    w = 2.2
    if x < y:
        print("x < y is true")
        if y < z:
            print("y < z is true, incrementing z")
            z = z + 1
        elif z < 4:
            print("z < 4 is true, setting z = x")
            z = x
    else:
        print("x < y is false, incrementing y")
        y = y + 1
    print("After if statements: x=" + str(x) + ", y=" + str(y) + ", z=" + str(z))
    return 0

if __name__ == "__main__":
        main()
