#ifndef __COMMON__H__
#define __COMMON__H__
#include <stdio.h>
#include <string>

void str_ltrim(std::string& str, const char* target);
void str_rtrim(std::string& str, const char* target);
void str_trim(std::string& str, const char* target);
bool file_exist(const char* file);
std::string get_file_content(const char* file);
std::string md5_str_to_uuid_str(std::string& md5_str);

#endif

