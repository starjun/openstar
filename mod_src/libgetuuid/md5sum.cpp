#include <stdio.h>
#include "md5sum.h"
#include <string.h>

using namespace std;

#define S11 7
#define S12 12
#define S13 17
#define S14 22
#define S21 5
#define S22 9
#define S23 14
#define S24 20
#define S31 4
#define S32 11
#define S33 16
#define S34 23
#define S41 6
#define S42 10
#define S43 15
#define S44 21

static inline unsigned long rotate_left(unsigned long x, unsigned long n) {
    // is unsigned long > 32 bit mask
#if ~0lu != 0xfffffffflu
    return (x << n) | ((x & 0xffffffffu) >> (32-n));
#else
    return (x << n) | (x >> (32-n));
#endif
}

static inline unsigned long F(unsigned long x, unsigned long y,
    unsigned long z) {
    return (x & y) | (~x & z);
}

static inline unsigned long G(unsigned long x, unsigned long y,
    unsigned long z) {
    return (x & z) | (y & ~z);
}

static inline unsigned long H(unsigned long x, unsigned long y,
    unsigned long z) {
    return x ^ y ^ z;
}

inline unsigned long I(unsigned long x, unsigned long y, unsigned long z) {
    return y ^ (x | ~z);
}


static void FF(unsigned long &a, unsigned long b, unsigned long c,
    unsigned long d, unsigned long x, unsigned long s, unsigned long ac) {
    a += F(b, c, d) + x + ac;
    a = rotate_left(a, s) + b;
}

static void GG(unsigned long &a, unsigned long b, unsigned long c,
    unsigned long d, unsigned long x, unsigned long s, unsigned long ac) {
    a += G(b, c, d) + x + ac;
    a = rotate_left(a, s) + b;
}

static void HH(unsigned long &a, unsigned long b, unsigned long c,
    unsigned long d, unsigned long x, unsigned long s, unsigned long ac) {
    a += H(b, c, d) + x + ac;
    a = rotate_left(a, s) + b;
}

static void II(unsigned long &a, unsigned long b, unsigned long c,
    unsigned long d, unsigned long x, unsigned long s, unsigned long ac) {
    a += I(b, c, d) + x + ac;
    a = rotate_left(a, s) + b;
}

MD5Sum::MD5Sum() {
    init();
    m_committed = false;
}

MD5Sum::MD5Sum(const char* sum) {
    init();
    m_committed = true;

    int i;
    int c;
    for(i = 0; i < 16; i++, sum += 2) {
        sscanf(sum, "%02x", &c);
        m_md5[i] = c;
    }
}

void MD5Sum::init() {
    m_count[0] = m_count[1] = 0;
    m_state[0] = 0x67452301;
    m_state[1] = 0xefcdab89;
    m_state[2] = 0x98badcfe;
    m_state[3] = 0x10325476;
    m_bpos = 0;
}

void MD5Sum::update(void) {
    unsigned long x[16], a, b, c, d;
    int i;

    if(!m_bpos)
        return;

    while(m_bpos < 64)
        m_buf[m_bpos++] = 0;
    m_bpos = 0;

    if((m_count[0] += 512) < 512)
        ++m_count[1];

    a = m_state[0];
    b = m_state[1];
    c = m_state[2];
    d = m_state[3];

    for(i = 0; i < 16; ++i)
        x[i] = (unsigned long)(m_buf[i * 4]) |
            (unsigned long)(m_buf[i * 4 + 1] << 8) |
            (unsigned long)(m_buf[i * 4 + 2] << 16) |
            (unsigned long)(m_buf[i * 4 + 3] << 24);

    FF(a, b, c, d, x[ 0], S11, 0xd76aa478);
      FF(d, a, b, c, x[ 1], S12, 0xe8c7b756);
      FF(c, d, a, b, x[ 2], S13, 0x242070db);
      FF(b, c, d, a, x[ 3], S14, 0xc1bdceee);
      FF(a, b, c, d, x[ 4], S11, 0xf57c0faf);
      FF(d, a, b, c, x[ 5], S12, 0x4787c62a);
      FF(c, d, a, b, x[ 6], S13, 0xa8304613);
      FF(b, c, d, a, x[ 7], S14, 0xfd469501);
      FF(a, b, c, d, x[ 8], S11, 0x698098d8);
      FF(d, a, b, c, x[ 9], S12, 0x8b44f7af);
      FF(c, d, a, b, x[10], S13, 0xffff5bb1);
      FF(b, c, d, a, x[11], S14, 0x895cd7be);
      FF(a, b, c, d, x[12], S11, 0x6b901122);
      FF(d, a, b, c, x[13], S12, 0xfd987193);
      FF(c, d, a, b, x[14], S13, 0xa679438e);
      FF(b, c, d, a, x[15], S14, 0x49b40821);

    GG(a, b, c, d, x[ 1], S21, 0xf61e2562);
    GG(d, a, b, c, x[ 6], S22, 0xc040b340);
    GG(c, d, a, b, x[11], S23, 0x265e5a51);
    GG(b, c, d, a, x[ 0], S24, 0xe9b6c7aa);
    GG(a, b, c, d, x[ 5], S21, 0xd62f105d);
    GG(d, a, b, c, x[10], S22,  0x2441453);
    GG(c, d, a, b, x[15], S23, 0xd8a1e681);
    GG(b, c, d, a, x[ 4], S24, 0xe7d3fbc8);
    GG(a, b, c, d, x[ 9], S21, 0x21e1cde6);
    GG(d, a, b, c, x[14], S22, 0xc33707d6);
    GG(c, d, a, b, x[ 3], S23, 0xf4d50d87);
    GG(b, c, d, a, x[ 8], S24, 0x455a14ed);
    GG(a, b, c, d, x[13], S21, 0xa9e3e905);
    GG(d, a, b, c, x[ 2], S22, 0xfcefa3f8);
    GG(c, d, a, b, x[ 7], S23, 0x676f02d9);
    GG(b, c, d, a, x[12], S24, 0x8d2a4c8a);

    HH(a, b, c, d, x[ 5], S31, 0xfffa3942);
    HH(d, a, b, c, x[ 8], S32, 0x8771f681);
    HH(c, d, a, b, x[11], S33, 0x6d9d6122);
    HH(b, c, d, a, x[14], S34, 0xfde5380c);
    HH(a, b, c, d, x[ 1], S31, 0xa4beea44);
    HH(d, a, b, c, x[ 4], S32, 0x4bdecfa9);
    HH(c, d, a, b, x[ 7], S33, 0xf6bb4b60);
    HH(b, c, d, a, x[10], S34, 0xbebfbc70);
    HH(a, b, c, d, x[13], S31, 0x289b7ec6);
    HH(d, a, b, c, x[ 0], S32, 0xeaa127fa);
    HH(c, d, a, b, x[ 3], S33, 0xd4ef3085);
    HH(b, c, d, a, x[ 6], S34,  0x4881d05);
    HH(a, b, c, d, x[ 9], S31, 0xd9d4d039);
    HH(d, a, b, c, x[12], S32, 0xe6db99e5);
    HH(c, d, a, b, x[15], S33, 0x1fa27cf8);
    HH(b, c, d, a, x[ 2], S34, 0xc4ac5665);

    II(a, b, c, d, x[ 0], S41, 0xf4292244);
    II(d, a, b, c, x[ 7], S42, 0x432aff97);
    II(c, d, a, b, x[14], S43, 0xab9423a7);
    II(b, c, d, a, x[ 5], S44, 0xfc93a039);
    II(a, b, c, d, x[12], S41, 0x655b59c3);
    II(d, a, b, c, x[ 3], S42, 0x8f0ccc92);
    II(c, d, a, b, x[10], S43, 0xffeff47d);
    II(b, c, d, a, x[ 1], S44, 0x85845dd1);
    II(a, b, c, d, x[ 8], S41, 0x6fa87e4f);
    II(d, a, b, c, x[15], S42, 0xfe2ce6e0);
    II(c, d, a, b, x[ 6], S43, 0xa3014314);
    II(b, c, d, a, x[13], S44, 0x4e0811a1);
    II(a, b, c, d, x[ 4], S41, 0xf7537e82);
    II(d, a, b, c, x[11], S42, 0xbd3af235);
    II(c, d, a, b, x[ 2], S43, 0x2ad7d2bb);
    II(b, c, d, a, x[ 9], S44, 0xeb86d391);

    m_state[0] += a;
    m_state[1] += b;
    m_state[2] += c;
    m_state[3] += d;

    m_committed = false;
}

void MD5Sum::commit(void) {
     static unsigned char pad[64] = {
            0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    if(isCommitted())
        return;

    unsigned char cbuf[8];
    unsigned long i, len;

    m_count[0] += (unsigned long)(m_bpos << 3);
    if(m_count[0] < (unsigned long)(m_bpos << 3))
        ++m_count[1];

    for(i = 0; i < 2; ++i)
    {
        cbuf[i * 4] = (unsigned char)m_count[i] & 0xff;
        cbuf[i * 4 + 1] = (unsigned char)((m_count[i] >> 8) & 0xff);
        cbuf[i * 4 + 2] = (unsigned char)((m_count[i] >> 16) & 0xff);
        cbuf[i * 4 + 3] = (unsigned char)((m_count[i] >> 24) & 0xff);
    }

    i = (unsigned) ((m_count[0] >> 3) & 0x3f);
    len = (i < 56) ? (56 - i) : (120 - i);
    if(len)
        put((const char*)pad, len);

    put((const char*)cbuf, 8);

    for(i = 0; i < 4; ++i) {
        m_md5[i * 4] = (unsigned char)m_state[i] & 0xff;
        m_md5[i * 4 + 1] = (unsigned char)((m_state[i] >> 8) & 0xff);
        m_md5[i * 4 + 2] = (unsigned char)((m_state[i] >> 16) & 0xff);
        m_md5[i * 4 + 3] = (unsigned char)((m_state[i] >> 24) & 0xff);
    }
    init();
    m_committed = true;
}

bool MD5Sum::isCommitted() const {
    //return (m_committed && !m_bpos);
    return m_committed;
}

void MD5Sum::put(const char* buf, unsigned int size) {
    while(size--) {
            m_buf[m_bpos++] = *(buf++);
            if(m_bpos >= 64)
                update();
    }
}

MD5Sum::operator const unsigned char*() {
    commit();
    return m_md5;
}

string MD5Sum::toString() {
    commit();
    return toString(m_md5);
}

string MD5Sum::toTempString() {
    char buf[512];
    //save state
    memcpy(buf, this, sizeof(MD5Sum));
    string result = toString();
    //restore state
    memcpy(this, buf, sizeof(MD5Sum));
    return result;
}

string MD5Sum::toString(const unsigned char* md5) {
    char buf[36];

    for(int i = 0; i < 16; ++i)
            snprintf(buf + 2 * i, 3, "%02x", (unsigned)md5[i]);
    buf[32] = 0;

    return buf;
}

bool MD5Sum::operator==(const MD5Sum& sum) {
    commit();
    //if(isCommitted() && sum.isCommitted()) {
    return (memcmp(m_md5, sum.m_md5, 16) == 0);
    //}
}

