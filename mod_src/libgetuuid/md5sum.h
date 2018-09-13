#ifndef __MD5SUM__H__
#define __MD5SUM__H__

#include <string>

class MD5Sum
{
protected:
	unsigned long m_state[4];
	unsigned long m_count[2];
	unsigned char m_buf[64];
	unsigned int  m_bpos;
	bool          m_committed;
	unsigned char m_md5[16];

	void init();
	void update();
	void commit();
	bool isCommitted() const;

public:
	MD5Sum();
	MD5Sum(const char* sum);

	void put(const char* buf, unsigned int size);

	operator const unsigned char*();
	std::string toString();
	std::string toTempString();

	bool operator==(const MD5Sum& sum);

	static std::string toString(const unsigned char* md5);
};

#endif

