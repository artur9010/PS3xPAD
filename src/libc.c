#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

void *memset(void *m, int c, size_t n)
{
	char *s = (char *) m;

	while (n-- != 0)
	{
		*s++ = (char) c;
	}

	return m;
}

void *memcpy(void *dst0, const void *src0, size_t len0)
{
	char *dst = (char *)dst0;
	char *src = (char *)src0;

	void *save = dst0;

	while (len0--)
		*dst++ = *src++;

	return save;
}

int memcmp(const void* s1, const void* s2,size_t n)
{
    const unsigned char *p1 = s1, *p2 = s2;
    while(n--)
        if( *p1 != *p2 )
            return *p1 - *p2;
        else
            *p1++,*p2++;
    return 0;
}


size_t strlen(const char *s) {
    const char *p = s;
    while (*s) ++s;
    return s - p;
}


char *strchr(const char *s, int c)
{
    while (*s != (char)c)
        if (!*s++)
            return 0;
    return (char *)s;
}


char *strstr(const char *s1, const char *s2)
{
    size_t n = strlen(s2);
    while(*s1)
        if(!memcmp(s1++,s2,n))
            return s1-1;
    return 0;
}


int strncasecmp (__const char *s1, __const char *s2, size_t n)
{
  int c1, c2;
  while (n > 0)
    {
      c1 = *((unsigned char *)(s1++));
      if (c1 >= 'A' && c1 <= 'Z')
        c1 = c1 + ('a' - 'A');
      c2 = *((unsigned char *)(s2++));
      if (c2 >= 'A' && c2 <= 'Z')
        c2 = c2 + ('a' - 'A');
      if (c1 != c2)
        {
          return (c1 - c2);
        }
      if (c1 == '\0')
        {
          return 0;
        }
      --n;
    }
  return 0;
}

int strcasecmp (__const char *s1, __const char *s2)
{
  int c1, c2, n;
  n=strlen(s1);
  while (n > 0)
    {
      c1 = *((unsigned char *)(s1++));
      if (c1 >= 'A' && c1 <= 'Z')
        c1 = c1 + ('a' - 'A');
      c2 = *((unsigned char *)(s2++));
      if (c2 >= 'A' && c2 <= 'Z')
        c2 = c2 + ('a' - 'A');
      if (c1 != c2)
        {
          return (c1 - c2);
        }
      if (c1 == '\0')
        {
          return 0;
        }
      --n;
    }
  return 0;
}

int strncmp(const char* s1, const char* s2, size_t n)
{
	if(n==0) return 0;
    while(*s1 && (*s1==*s2))
	{
        s1++,s2++;
		n--;
		if(n==0) break;
	}
    return *(const unsigned char*)s1-*(const unsigned char*)s2;
}

int strcmp(const char* s1, const char* s2)
{
    while(*s1 && (*s1==*s2))
        s1++,s2++;
    return *(const unsigned char*)s1-*(const unsigned char*)s2;
}


char *strcpy(char *dest, const char* src)
{
    char *ret = dest;
    while (*dest++ = *src++)
        ;
    return ret;
}


char *strncpy(char *dest, const char *src, size_t n)
{
    char *ret = dest;
    do {
        if (!n--)
            return ret;
    } while (*dest++ = *src++);
    while (n--)
        *dest++ = 0;
    return ret;
}

char *strcat(char *dest, const char *src)
{
    char *ret = dest;
    while (*dest)
        dest++;
    while (*dest++ = *src++)
        ;
    return ret;
}

char *strtok(char * str, const char * delim)
{
    static char* p=0;
    if(str)
        p=str;
    else if(!p)
        return 0;
    str=p+strspn(p,delim);
    p=str+strcspn(str,delim);
    if(p==str)
        return p=0;
    p = *p ? *p=0,p+1 : 0;
    return str;
}

size_t strcspn(const char *s1, const char *s2)
{
    size_t ret=0;
    while(*s1)
        if(strchr(s2,*s1))
            return ret;
        else
            s1++,ret++;
    return ret;
}

size_t strspn(const char *s1, const char *s2)
{
    size_t ret=0;
    while(*s1 && strchr(s2,*s1++))
        ret++;
    return ret;
}

static void outc(char **dst, size_t *left, int *len, char c)
{
    if (*left > 1) {
        **dst = c;
        (*dst)++;
        (*left)--;
    }
    (*len)++;
}

static void outs(char **dst, size_t *left, int *len, const char *s)
{
    if (!s) s = "";
    while (*s) outc(dst, left, len, *s++);
}

static void outu(char **dst, size_t *left, int *len, unsigned int v, unsigned int base, int width, int zero)
{
    char tmp[16];
    int n = 0;

    do {
        unsigned int d = v % base;
        tmp[n++] = (char)(d < 10 ? '0' + d : 'a' + d - 10);
        v /= base;
    } while (v);
    while (n < width) tmp[n++] = zero ? '0' : ' ';
    while (n) outc(dst, left, len, tmp[--n]);
}

int snprintf(char *str, size_t size, const char *fmt, ...)
{
    va_list ap;
    int rv;
    va_start(ap, fmt);
    rv = vsnprintf(str, size, fmt, ap);
    va_end(ap);
    return rv;
}

static int
_vsnprintf_inner(char *str, size_t size, const char *fmt, va_list ap)
{
    char *dst = str;
    size_t left = size;
    int len = 0;

    while (*fmt) {
        if (*fmt != '%') {
            outc(&dst, &left, &len, *fmt++);
            continue;
        }
        fmt++;
        if (*fmt == '0') fmt++;
        if (*fmt == '4') fmt++;
        switch (*fmt++) {
        case 's':
            outs(&dst, &left, &len, va_arg(ap, const char *));
            break;
        case 'd': {
            int v = va_arg(ap, int);
            if (v < 0) {
                outc(&dst, &left, &len, '-');
                v = -v;
            }
            outu(&dst, &left, &len, (unsigned int)v, 10, 0, 0);
            break;
        }
        case 'u':
            outu(&dst, &left, &len, va_arg(ap, unsigned int), 10, 0, 0);
            break;
        case 'x':
            outu(&dst, &left, &len, va_arg(ap, unsigned int), 16, 4, 1);
            break;
        case 'l': {
            if (*fmt == 'l') { fmt++; }
            if (*fmt == 'u') {
                outu(&dst, &left, &len, va_arg(ap, unsigned long long), 10, 0, 0);
                fmt++;
            } else if (*fmt == 'x') {
                outu(&dst, &left, &len, va_arg(ap, unsigned long long), 16, 0, 0);
                fmt++;
            } else if (*fmt == 'd') {
                long long v = va_arg(ap, long long);
                if (v < 0) {
                    outc(&dst, &left, &len, '-');
                    v = -v;
                }
                outu(&dst, &left, &len, (unsigned long long)v, 10, 0, 0);
                fmt++;
            }
            break;
        }
        case '%':
            outc(&dst, &left, &len, '%');
            break;
        }
    }
    va_end(ap);
    if (size) *dst = 0;
    return len;
}

int vsnprintf(char *str, size_t size, const char *fmt, va_list ap)
{
    return _vsnprintf_inner(str, size, fmt, ap);
}
