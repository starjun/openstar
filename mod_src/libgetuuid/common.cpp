#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <string>

void str_ltrim(std::string& str, const char* target) {
    const char* lpsz = str.c_str();
    const char* p = lpsz;
    for (; *p; p++) {
        if (strchr(target, *p) == NULL) {
            break;
        }
    }
    if (p > lpsz) {
        str.erase(0, p - lpsz);
    }
}

void str_rtrim(std::string& str, const char* target) {
    const char* lpsz = str.c_str();
    const char* lpszLast = NULL;

    for (const char* p = lpsz; *p; p++) {
        if (strchr(target, *p) != NULL) {
            if (lpszLast == NULL) {
                lpszLast = p;
            }
        } else {
            lpszLast = NULL;
        }
    }

    if (lpszLast != NULL) {
        str.resize(lpszLast - lpsz);
    }
}

void str_trim(std::string& str, const char* target) {
    str_ltrim(str, target);
    str_rtrim(str, target);
}

bool file_exist(const char* file) {
    struct stat buffer;
    int ret = stat(file, &buffer);
    if (ret != 0 || (buffer.st_mode & S_IFREG) != S_IFREG) {
        return false;
    } else {
        return true;
    }
}

std::string get_file_content(const char* file) {
    std::string ret;
    FILE* fp = fopen(file, "rb");
    if (NULL == fp) {
        return "";
    }

    char* buf[1024];
    for (;;) {
        memset(buf, 0, sizeof (buf));
        size_t read_size = fread(buf, 1, sizeof (buf), fp);
        if (read_size == 0) {
            break;
        }
        ret.append(reinterpret_cast<char*> (buf), read_size);

    }
    fclose(fp);

    str_trim(ret, " \t\r\n\"");
    return ret;
}

std::string md5_str_to_uuid_str(std::string& md5_str) {
    if (md5_str.length() == 32) {
        md5_str.insert(8, "-");
        md5_str.insert(13, "-");
        md5_str.insert(18, "-");
        md5_str.insert(23, "-");
    }
    return md5_str;
}

