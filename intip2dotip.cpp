#include<iostream>
using namespace std;
union IP
{
unsigned long ip;
 unsigned char s[4];  //无符号型长度为4的数组
};
int main()
{
 unsigned long m;
 int i;
 IP r;
 cout<<"请输入一个ip地址:"<<endl;
 cin>>m;
 int v =m;
 r.ip = m;
 cout<<"ip地址的点分十进制形式是:"<<endl;

 //big ending and little ending make  a difference
 for(i = 0;i<4;i++)
 {
  cout<<(int)r.s[i];
  if(i!=3)
   cout<<".";
 }
 return(0);
}
