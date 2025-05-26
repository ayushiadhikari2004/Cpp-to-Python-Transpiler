#include <iostream>
using namespace std;

class Point {
    public:
        int x;
        int y;
};

int main() {
    Point p;
    p.x = 10;
    p.y = 20;
    cout << p.x << " " << p.y << endl;
    return 0;
} 