/* 
IF nested 
valid
*/
#include <iostream>
#include <fstream>
using namespace std;

int main () {

int x = 1;
int y = 2;
int z = 3;
bool b = true;
float q = 1.1;
float w = 2.2;

if (x < y)
{ 
    cout << "x < y is true" << endl;
    if (y < z)
    {
        cout << "y < z is true, incrementing z" << endl;
        z++;
    }
    else if (z < 4)
    {
        cout << "z < 4 is true, setting z = x" << endl;
        z=x;
    }
}
else 
{
    cout << "x < y is false, incrementing y" << endl;
    y++;
}

cout << "After if statements: x=" << x << ", y=" << y << ", z=" << z << endl;

return 0;
}
