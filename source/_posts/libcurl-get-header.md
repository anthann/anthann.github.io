---
title: 使用curl或libcurl查看HTTP响应头
date: 2019-01-21 21:22:24
tags: cURL, libcurl, HEAD, HTTP
---

最近有一个需求是这样的：拿到一个HTTP协议的URL，判定指向的资源是否是图片。  

一个常规做法是向URL发起请求，然后看响应头里面`Content-Type`来得知资源的MIME信息。这个场景下我们只需要拿到Response Header，可以舍弃Body部分。嗯，典型的Method `HEAD`的用法。  
  
## curl  
  
熟悉curl的同学可能会在terminal敲下这段命令：  

```
curl -I http_url
```

这句命令将向服务器发送一个HTTP method为`HEAD`的请求，正常情况下将获得类似下面这样的信息：  

```
HTTP/1.1 200 Connection established

HTTP/1.1 200 OK
Connection: keep-alive
Content-Type: img/png
Access-Control-Allow-Origin: *
Content-Length: 5057
```

通过其中的`Content-Type`我们可以知道指向的资源是图片。  

当然了，有的服务器不支持`HEAD`请求，以上命令会返回`405 Method Not Allowed`错误。解决方法也简单，在命令里加上`-X GET`参数把method改写成`GET`:  

```
curl -X GET -I url
```

## libcurl  

以上是如何在Terminal通过cURL命令获取HTTP响应头。很多时候我们是在项目代码里需要检查响应的`Content-Type`，怎么做呢？  

对于C语言来说，可以使用[libcurl](https://curl.haxx.se/libcurl/)。C++、Objective-C、Swift亦可直接或间接使用libcurl，其他语言通常也有对应的库/包。以下以C语言代码为例。    

首先我们先定义接收响应内容的数据结构：  

```c
struct string {
    char *ptr;
    size_t len;
};

void init_string(struct string *s) {
    s->len = 0;
    s->ptr = malloc(s->len+1);
    if (s->ptr == NULL) {
        fprintf(stderr, "malloc() failed\n");
        exit(EXIT_FAILURE);
    }
    s->ptr[0] = '\0';
}
```

然后，需要定义一个写函数，这个函数会不断的把数据追加进传入的指针：  

```c
// ptr：src地址
// size*nmemb：数据长度
// s: dest地址
size_t writefunc(void *ptr, size_t size, size_t nmemb, struct string *s) {
    size_t new_len = s->len + size*nmemb;
    s->ptr = realloc(s->ptr, new_len+1);
    if (s->ptr == NULL) {
        fprintf(stderr, "realloc() failed\n");
        exit(EXIT_FAILURE);
    }
    memcpy(s->ptr+s->len, ptr, size*nmemb);
    s->ptr[new_len] = '\0';
    s->len = new_len;
    
    return size*nmemb;
}
```

接下来，我们一步步用libcurl实现上一节cURL一样的功能。  

* 初始化CURL对象  

```c
CURL *curl = curl_easy_init();
CURLcode res = CURLE_OK;
// 响应将被存储进s
struct string s;
init_string(&s);
```

* 如果初始化成功，设置请求参数  

```c
// 设置请求的url地址
curl_easy_setopt(curl, CURLOPT_URL, url);
// 不需要响应的body
curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
// 需要打印响应的header
curl_easy_setopt(curl, CURLOPT_HEADER, 1L);
// 设置写函数writefunc和目标地址s，当收到响应后会不断调用writefunc并把数据追加到s指向的地址
curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writefunc);
curl_easy_setopt(curl, CURLOPT_WRITEDATA, &s);
```

* 最后，发起请求，清理现场  

```c
res = curl_easy_perform(curl);
curl_easy_cleanup(curl);
printf("%s\n", s.ptr);
free(s.ptr);
```

正常情况下命令行里打出了响应头信息。  

`CURLOPT_HEADER`把请求的HTTP Method设置为`HEAD`，如果服务器不支持则会收到405错误。解决方法是试着把HTTP Method强制改回`GET`。  

查看文档，很快发现了这条语句: `curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);`。加在`CURLOPT_HEADER`后面，问题解决。  

有人遇到用`CURLOPT_HTTPGET`没有把Method改回`GET`的情况，可以试下用`curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "GET");`。  

[完整代码](https://gist.github.com/anthann/a0f21eea02a57b5f53f9551f49cc1017)

## 总结

本文分别用`curl`和`libcurl`演示了如何获取HTTP Response HEAD。常规做法是直接发送一个method为`HEAD`的请求；对于不支持`HEAD`的服务器，本文还提供了使用`GET`请求达到相同效果的方法。  