
配置使用介绍：
并配合解析样例进行说明。


## host和method规则配置
在一些场景中我们需要限制准入的host和允许的method（CDN&&前端服务器）
如我们仅允许域名为\*.test.com，method仅允许get和post；那么我们就配置host\_method_Mod.json文件

---
    {
        "state": "on",
        "method": [["GET","POST"],"list"],
        "hostname": ["*\\.test\\.com","jio"]
    }
    或者：
    {
        "state": "on",
        "method": ["^(get|post)$","jio"],
        "hostname": ["*\\.test\\.com","jio"]
    }

    下面的这个配置表示允许所有host，method仅允许GET
    {
        "state": "on",
        "method": ["GET",""],
        "hostname": ["*",""]
    }

配置规则就是这样，请多测试几次，就熟悉了，也是比较简单；关于这个jio的意思，其实就是`ngx.re.find(参数1,参数2,"jio")` 这里使用，区分大小写就是：`jo`；具体的一些参数请参考http://blog.csdn.net/weiyuefei/article/details/38439017

## 获取用户真实ip设置
在一些应用场景下，需要从http头的某一字段中获取用户真实IP，一般默认用`X-Forwarded-For` 或者 `X-Real-IP`，但是有时会被黑客伪装（没有设置remote Ip源），以及一些CDN厂商自定义的http头（CDN-SOURCE-IP），故就需要我们配置那个host，从哪些remote ip 来的，取http头中哪个标记字段
如host是id.test.com从192.168.10.6-8来的ip，从http头my-ip-real中获取；那么就需要配置realIpFrom_Mod.json文件

---
    {
    "id.test.com": {
        "ips": [[
            "192.168.10.8",
            "192.168.10.7",
            "192.168.10.6"
        ],"list"],
        "realipset": "my_ip_real"
    }
    }
    #如果要配置是所有来源IP
    {
    "id.test.com": {
        "ips":"*",
        "realipset": "my_ip_real"
    }
    }
    #使用字典(dict)匹配ips
    {
    "id.test.com":{"ips":[{"1.1.1.1":true,"2.2.2.2:5460":true},"dict"],
    "realipset":"x_for_f"}
    }

    #使用cidr匹配ips,使用ip段方式表示
    #2016年9月18日添加
    {
    "id.test.com":{"ips":[["1.1.1.1/24","123.12.32.12/24"],"cidr"],
    "realipset":"x_for_f"}
    }

说明一下，目前host为节点，目前不支持通过正则或者字典(dict)来匹配host。

## 配置自定义规则

`deny` ：就是应用层拒绝访问了，如果一些uri我们不需要外部可以访问(白名单IP不受该限制)

---
    {
        "state": "on",
        "action": ["deny"],
        "hostname": ["127.0.0.1",""],
        "uri": ["^/([\\w]{4}\\.html|deny\\.do|你好\\.html)$","jio"]
    }
    ```
    基础匹配hostname，uri，host为`127.0.0.1`，uri进行正则匹配，如果匹配成功，就执行`action`操作，这里就是拒绝访问。

    `rehtml`：这个动作就是返回字符串
    ```
    {
        "state": "on",
        "action": ["rehtml"],
        "rehtml": "hi~!",
        "hostname": ["127.0.0.1",""],
        "uri": ["/rehtml",""]
    }

这个也比较好理解，host是`127.0.0.1`，url通过字符串匹配，匹配成功就把`rehtml`中的内容直接返回了，应用场景也是比较多的。

`refile`：这个动作就是返回`./index`目录下文件的内容了，看个例子吧

---
    {
        "state": "on",
        "action": ["reflie"],
        "reflie": "2.txt",
        "hostname": ["127.0.0.1",""],
        "uri": ["^/refile$","jio"]
    }


`relua/relua_str`：这个动作就是执行lua脚本文件

---
    {
        "state": "on",
        "action": ["relua"],
        "relua":"1.lua",
        "hostname": ["*",""],
        "uri": ["/api/time",""]
    }

这个匹配规则，host是所有的，uri也是所有，匹配成功后执行`./index`目录下的1.lua文件
如果有一些复杂的可以直接使用lua脚本去实现，这个脚本的意思是匹配任意host，uri是`/api/time`

`log`：这个就表示仅仅记录一些log（log保存的路径就是在config.json里面，文件名是app_log.log）

---
    {
        "state": "on",
        "action": ["log"],
        "hostname": ["127.0.0.1",""],
        "uri": ["^/log$","jio"]
    }

比较好理解，注意hostname和uri的匹配方式（二阶匹配）

**这个场景也是比较多，就是对某个文件夹（uri路径、程序后台路径、phpmyadmin 等这样管理后台，通过IP访问控制）这样可以精细到文件夹的IP访问控制（非常实用的功能）**。

---
    {
        "state": "on",
        "action": ["deny"],
        "hostname": [["101.200.122.200","127.0.0.1"],"list"],
        "uri": ["/api/.*","jio"],
        "app_ext":[
        ["ip",[["106.37.236.170","1.1.1.1"],"list",true]]
        ]
    }

这个配置就表示，访问`/api/.*`这些目录的只有`ip`为`1.1.1.1`和`106.37.236.170`，是不是很简单，对目录进行明细的IP访问控制。

在看一个规则列表的可以使用or连接的

---
    {
        "state": "on",
        "action": ["deny"],
        "hostname": [["101.200.122.200","127.0.0.1"],"list"],
        "uri": ["/api/.*","jio"],
        "app_ext":[
        ["uri",["admin","in"],"or"],
        ["cookie",["c_test","jio"],"and"],
        ["ip",[["1.1.1.1","127.0.0.1"],"list",true],"and"]
        ]
    }

理解一下就是 hostname and uri and (app\_ext),app\_ext = (uri 包含 admin or cookie 正则匹配 c\_test) and ip not 不在列表(list)中。hostname 和 uri 是基础的条件，满足后再匹配app_ext 中的规则列表。
说明：[是否取反,匹配规则名称,规则明细,and/or连接符]
规则名称支持：remoteIp host method uri request\_uri useragent referer cookie query\_string ip 以及 args headers




## 配置referer过滤
在该模块下，一些防盗链，站外CSRF等都是在这里设置，如我需要设置图片仅允许本站进行引用。

---
    {
        "state": "on",
        "uri": [
            "\\.(gif|jpg|png|jpeg|bmp|ico)$",
            "jio"
        ],
        "hostname": [
            "www\\.test\\.com",
            ""
        ],
        "referer": [
            "\\.*.test.com",
            "jio"
        ],
        "action":"allow"
    }

上面的配置就是`www.test.com`这个网站的图片资源仅允许`referer`是`*.test.com`来的，如果`referer`不对就拒绝访问了，如果`action`是`allow`那么匹配到的这些url将不会进行后面的规则匹配，这样就减少规则匹配，提高效率
在看一个例子，就是防止站外的CSRF了(浏览器发起的)。

---
    {
        "state": "on",
        "uri": [
            "^/abc.do$",
            "jio"
        ],
        "hostname": [
            "pass.test.com"
            ""
        ],
        "referer": [
            "^.*/(www\\.test\\.com|www3\\.test\\.com)$",
            "jio",
            true
        ],
        "action":"deny"

    }

上面的这个配置就是uri`abc.do`的请求referer来源进行了限制，否则就拒绝访问，且`action`是`next`就表示，后续的规则匹配继续，1.2版本之前会bypass的。现在不会了。

## 配置uri过滤
url的过滤当然就是一些敏感文件目录啥的过滤了，看个例子吧

---
    {
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "uri": [
            "\\.(svn|git|htaccess|bash_history)",
            "jio"
        ],
        "action": "deny"
    }

首先看`hostname`,这里匹配的是所有，`uri`就是一些敏感文件、目录了，动作`action`就是拒绝了。
在说一个动作是`allow`的，这个场景就是一些静态资源，这些匹配后，不进行后续的规则匹配，总体是减少匹配的次数，提高效率的，因为不需要在不同的`location`中单独去引用LUA文件了，也是非常实用的功能

---
    {
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "uri": [
            "\\.(css|js|flv|swf|zip|txt)$",
            "jio"
        ],
        "action": "allow"
    }

上面的例子也是比较好理解的，不做解释了。
**这里的规则是[loveshell][1]总结的，后面的多数规则都是直接用loveshell的**

## 配置header过滤
这里`header`过滤了，比如一些扫描器特征，wvs的`header`在默认是有一个标记的`Acunetix_Aspect`,来个例子[注意在http的header中是：`Acunetix-Aspect`]

---
    {
    "state": "on",
    "uri": ["*",""],
    "hostname": ["*",""],
    "header": ["Acunetix_Aspect","*",""]
    }

这个例子就是拦截wvs扫描器的。

>占位符，后续会更新一些慢速攻击的特征

## 配置useragent过滤
`useragent`的过滤，一些脚本语言带的`agent`默认都给过滤了（ab 也过滤了）。

---
    {
        "state": "on",
        "id":"1-scan",
        "useragent": [
            ["HTTrack","harvest","audit","dirbuster",
             "pangolin","nmap","sqln","-scan","hydra",
             "Parser","libwww","BBBike","sqlmap","w3af",
             "owasp","Nikto","fimap","havij","PycURL","zmeu",
             "BabyKrokodil","netsparker","httperf","bench"
            ],
            "rein_list"
        ],
        "hostname": ["*",""]
    }


## 配置cookie过滤
关于`cookie`过滤，一般就是SQL注入等问题。

---
    {
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "cookie": ["select.+(from|limit)","jio"],
        "action": "deny"
    }

关于SQL注入需要根据自己的业务进行相应的调整，这样就可以更全面的防护。

## 配置get/post参数过滤
`get/post`参数的过滤就是SQL/XSS等问题（就是args\_Mod.json和post\_Mod.json）。参数污染是绕过不了的。

参考http://www.freebuf.com/articles/web/36683.html；
参考http://drops.wooyun.org/tips/132

一些waf的bypass技巧。我们根据自己的业务进行调整即可。
**这个一定要根据实际情况配置**

---
    {
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "args_data": ["sleep\\((\\s*)(\\d*)(\\s*)\\)","jio"],
        "action": "deny"
    }
    // -- XSS
    {
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "args_data": ["\\<(iframe|script|body|img|layer|div|meta|style|base|object|input)","jio"],
        "action": "deny"
    }

这些规则默认集成的[loveshell][1]，一定要根据自己的业务场景进行调整。抓过菜刀连接的数据包的人应该清楚，这里我们也可以进行过滤。

## 配置网络访问频率限制
关于访问频率的限制，支持对明细`url`的单独限速，当然也可以是整站的频率限制。

---
    -- 单个URI的频率限制
    -- 因为一个网站一般情况下容易被CC的点就那么几个
    {
        "state": "on",
        "network":{"maxReqs":10,"pTime":10,"blackTime":600},
        "hostname": [["101.200.122.200","127.0.0.1"],"list"],
        "uri": ["/api/time",""]
    }
    -- 限制整个网站的（范围大的一定要放下面）
    {
        "state": "on",
        "network":{"maxReqs":30,"pTime":10,"blackTime":600},
        "hostname": [["101.200.122.200","127.0.0.1"],"list"],
        "uri": ["*",""]
    }
    -- 限制ip的不区分host和url
    {
        "state": "on",
        "network":{"maxReqs":100,"pTime":10,"blackTime":600},
        "hostname": ["*",""],
        "uri": ["*",""]
    }

一定要根据自己的情况进行配置！！！

## 配置返回内容的替换规则

---
    {
        "state": "on",
        "uri": ["^/api/ip_dict$","jio"],
        "hostname": ["101.200.122.200",""],
        "replace_list":
            [
             ["deny","","denyFUCK"],
             ["allow","","allowPASS"],
             ["lzcaptcha\\?key='\\s*\\+ key","jio","lzcaptcha?keY='+key+'&keytoken=@token@'"]
            ]
    }

这里就不在解释了，注意的是`replace_list`这个是个内容替换的list，`@token@`就是动态的替换成服务器生成的`token`了。


## host_Mod 配置
其对应文件在`conf_json/host_json/host_Mod.json` 和 `conf_json/host_json/$host.json`
先看2个列子,比较好理解

---
    [
        {
            "state": "on",
            "action":"deny",
            "uri": ["/post.html",""],
            "post_form":1024,
            "app_ext":[
            ["post_form",["\\.(jpg|jpeg|png|webp|gif)$","jio",["image0",2],true],"or"],
            ["post_form",["(;|-|/)","jio",["image0",2]]]
            ]
        },
        {
            "state": "on",
            "action":["deny","network"],
            "network":{"maxReqs":30,"pTime":10,"blackTime":600},
            "uri": ["/index.html",""]
        }
    ]


[1]: https://github.com/loveshell/ngx_lua_waf
