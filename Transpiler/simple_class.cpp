#include <iostream>
using namespace std;

class Simple {
    private:
        int value;
    
    public:
        void setValue(int v) {
            value = v;
        }

        int getValue() {
            return value;
        }
};

int main() {
    Simple obj;
    obj.setValue(42);
    cout << obj.getValue() << endl;
    return 0;
} 