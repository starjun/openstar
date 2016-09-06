---
title: OpenStar(开心)说明
tags: OpenResty,OpenStar,waf+,云waf,nginx lua
grammar_cjkRuby: true

---


欢迎使用 **{OpenStar}(WAF+)**，该项目是从实际需求中产生，用于解决当时实际出现的问题，经过多次的版本迭代到今天，实属不易。感谢**春哥**，该项目是解决工作的实际问题一点一滴积累的经验，特别感谢[春哥][1]的神器（**[OpenResty][2]**）
**代码写的比较好理解，肯定不优雅  哈~**

# 概览


----------


**OpenStar**是一个基于[OpenResty][2]的，高性能WAF，还相应增加了其他灵活、友好、实用的功能，是增强的WAF。
# WAF防护


----------


在**OpenStar**中的WAF防护模块，采用传统的黑白名单、包含、优化正则过滤的方式（*有人会问现在不是流行自主学习么；正则、黑白名单会有盲点、会被绕过......*）。这里我简单说明一下，自主分析学习引擎是我们的日志分析引擎做的，这里是高性能、高并发的点，就用简单粗暴的方法解决，根据业务实际调整好防护策略，可以解决绝大多数WEB安全1.0和WEB安全2.0类型的漏洞（90%+的问题）。
WAF	防护从header,args,post,访问频率等，分层进行按顺序防护，详细在后面的功能会详细说明

 - **WEB安全1.0**
   在1.0时代下，攻击是通过服务器漏洞（IIS6溢出等）、WEB应用漏洞（SQL注入、文件上传、命令执行、文件包含等）属于服务器类的攻击，该类型漏洞虽然经历了这么多年，很遗憾，此类漏洞还是存在，并且重复在犯相同的错误。

 - **WEB安全2.0**
   随着社交网络的兴起，原来不被重视的XSS、CSRF等漏洞逐渐进入人们的视野，那么在2.0时代，漏洞利用的思想将更重要，发挥你的想象，可以有太多可能。

 - **WEB安全3.0**
   同开发设计模式类似（界面、业务逻辑、数据），3.0将关注应用本身的业务逻辑和数据安全，如密码修改绕过、二级密码绕过、支付类漏洞、刷钱等类型的漏洞，故注重的是产品本身的业务安全、数据安全、风控安全等。
   
   > `安全不仅仅是在技术层面、还应该在行政管理层面、物理层面去做好安全的防护，才能提供最大限度的保护。`
   > 安全行业多年的从业经验：人，才是最大的威胁；无论是外部、内部、无心、有意过失。（没有丑女人、只有懒女人）我想可以套用在此处，纯属个人见解。
 
# CC/采集防护
什么是**CC攻击**，简单的说一下，就是用较少的代价恶意请求web（应用）中的重资源消耗点（CPU/IO/数据库等等）从而达到拒绝服务的目的；**数据采集**，就是内容抓取了，简单这么理解吧
> `非官方学术类的解释，先将就理解下`
**关于本文对CC攻击的分析和相关的防护算法，都是我在实战中分析总结，并形成自己的方法论，不足之处、欢迎指正。**

## 攻击类型
 - 行为（GET、POST等）
  目前主要还是这两中method攻击为主，其他的少之又少。
 - 被攻击的点
 
    1：用户可直接访问的URL（搜索、重CPU计算、IO、数据库操作等）
     
    2：嵌入的URL（验证码、ajax接口等）
     
    3：面向非浏览器的接口（一些API、WEBservice等）

    4：基于特定web服务、语言等的特定攻击（慢速攻击、PHP-dos等） 
 
> `面对CC攻击我们需要根据实际情况采用不同的防护算法`

## 防护方法
 - 网络层
 通过访问ip的频率、统计等使用阀值的方式进行频率和次数的限制，黑名单方式
 
- 网络层+应用层
 在后来的互联网网络下，有了的CDN加入，现在增加的网络层的防护需要扩展，那么统计的IP将是在HTTP头中的IP，仍然使用频率、次数、黑名单的方式操作。 
 > `但是很多厂家的硬件流量清洗等设备，有的获取用户真实IP从HTTP头中取的是固定字段（X-FOR-F），不能自定义，更甚至有的厂家就没有该功能，这里就不说具体的这些厂家名字了`PS: 在传统的4层防护上，是没有问题的

-  应用层 
TAG验证、SET COOKIE、URL跳转、JS跳转、验证码、页面嵌套、强制静态缓存等
防护是需要根据攻击点进行分别防护的，如攻击的是嵌入的url，我们就不能使用JS跳转、302验证码等这样的方法；**在多次的CC防护实战中，如使用url跳转、set cookie，在新型的CC攻击下，这些防护都已经失效了**。后面我会分享一下我的防护算法，并且在**OpenStar**中已经可以根据情况实现我所说的防护算法。
浏览器是可以执行JS和flash的，这里我分享一些基于JS的防护算法，flash需要自己去写（比js复杂一些），可以实现flash应用层的安全防护和防页面抓取（开动你的大脑吧）

1：客户端防护
使用JS进行前端的防护（浏览器识别、鼠标轨迹判断、url有规则添加尾巴（args参数）、随机延迟、鼠标键盘事件获取等）其实这里非常复杂，如浏览器的识别 ie 支持 `!-[1,]` 这个特殊JS，一些浏览器有自定义标签等等；

2：服务端防护
url添加的尾巴（args参数）是服务器动态生成的token，而不是使用静态的正则去匹配其合法性。

3：特定攻击
该类特定攻击，可以通过特征快速匹配出来（慢速攻击、PHP5.3的http头攻击）

**简单场景**

1：用户可直接访问的url（这种是最好防的）

第一阶段：

 - 网络层：访问频率限制，超出阀值仅黑名单一段时间

 - 应用层：js跳转、验证码、flash策略（拖动识别等）

2：嵌入的url（ajax校验点、图片验证码）

第一阶段：

 - 网络层：访问频率限制，超出阀值仅黑名单一段时间

 - 应用层：载入被攻击的url页面，重写页面，使用js方操作链接被攻击的url。js随机在url尾巴增加有一定规则的校验串，服务端对串进行静态正则校验。

第二阶段：

 - 网络层+应用层：用户ip在http头中，需要从http头取ip，在进行频率限制
（其实做好了，这一层的防护，基本不用进入第三阶段的应用层防护了）
 
 - 应用层：校验串使用服务端生成的token，进行严格服务器token验证检查

第三阶段：

 - 应用层：js增加浏览器识别（不同agent匹配不同js识别代码）、鼠标轨迹验证、键盘鼠标事件验证等js增加验证后，在进行校验串生成。

> 应用层的防护是在网络层+扩展的网络层防护效果不佳时使用，一般情况基本用的不多，因为在OpenStar的防护下，极少数情况下，需要第三阶段防护。在防页面抓取时，发挥你的想象（js是个好帮手，善用）使用OpenStar就可以帮你快速实现；当然使用flash防抓取效果更好（不够灵活）。

# 目录

后续更新！~

# 下载

wget

git clone 

**已经打包的一些脚本，请参考bash目录**

# 安装
 - 安装OpenResty
 这里不做过多重复描述，直接看链接[OpenResty][2]
 - 配置nginx.conf
 在http节点，引用waf.conf。注：原ngx相关配置基本不用修改，该优化优化、该做CPU亲缘绑定继续、该动静分离还继续、该IO、TIME等优化继续不要停。
 - 配置waf.conf
 修改lua\_package\_path，使用正确的路径即可；修改那些lua文件的路径，多检查几遍。
 - 设置目录权限
 OpenStar目录建议放到OR下，方便操作，该目录ngx运行用户有读写执行权限即可。因为要写日志，*暂时没有用ngx.log，后续可能会改动*。
 - lua文件修改
 在init.lua中，修改conf_json参数，config.json文件绝对路径根据自己的情况写正确。
 - api使用
2016年6月7日 23:31:09 更新啦，引用waf.conf，后就可以直接使用api接口了，通过监听5460端口来给管理用啦，界面也在筹划中，期待有人可以加入，帮我一起整界面。

**已经打包的一些脚本，请参考bash目录，运行前请阅读一下，感谢好友余总帮助写的脚本**

# 使用

## 配置规则

一般情况下匹配某一规则由2个参数组成，第二个参数标识第一个参数类型

hostname：`["*",""]` 

==>表示匹配所有域名（使用字符串匹配，非正则，非常快）

hostname：`["*\\.game\\.com","jio"]` 

==>表示使用正则匹配host（**ngx.re.find($host,参数1，参数2)**）

hostname：`[["127.0.0.1","127.0.0.1:8080"],"table"]` 

==>表示匹配参数1列表中所有host

hostname：`[{"127.0.0.1":true,"127.0.0.1:5460":true},"list"]` 

==>表示匹配list中host为true的host

hostname：`["127.0.0.1","in"]` 

==>表示匹配host中包含127.0.0.1的host

## 执行流程

![enter description here][3]

 - init阶段
 
 a：首先加载本地的config.json配置文件，将相关配置读取到config_dict,host_dict,ip_dict中
 
 - access阶段（自上到下的执行流程，规则列表也是自上到下按循序执行的）
 
 0：realIpFrom_Mod ==> 获取用户真实IP（从HTTP头获取，如设置）
 
 1：ip_Mod ==> 请求ip的黑/白名单、log记录
 
 2：host\_method\_Mod ==> host和method过滤（白名单）
 
 3：rewrite_Mod ==> 跳转模块，set-cookie操作

 4：host_Mod ==> 对应host执行的规则过滤（url,referer,useragent）
 
 5：app_Mod ==> 用户自定义应用层过滤
 
 6：referer_Mod ==> referer过滤（黑/白名单、log记录）
 
 7：url_Mod ==> url过滤（黑/白名单、log记录）
 
 8：header_Mod ==> header过滤（黑名单）
 
 9：useragent_Mod ==> useragent过滤（黑/白名单、log记录）
 
 10：cookie_Mod ==> cookie过滤（黑/白名单、log记录）
 
 11：args_Mod ==> args参数过滤（黑/白名单、log记录）
 
 12：post_Mod ==> post参数过滤（黑/白名单、log记录）
 
 13：network_Mod ==> 应用层网络频率限制（频率黑名单）

 - body阶段
 
 14：replace\_Mod ==> 内容替换规则（动态进行内容替换，性能消耗较高慎用，可以的话用app\_Mod中rehtml、refile这2个自定义action）
 
## 主配置

  config.json文件进行配置，主要是一些参数开关、目录设置
  注：以下表示法，"on"表示开启，"off"表示关闭。
  ```

{
  "openstar_version":"v 1.3",  
  #该参数就是OpenStar标记版本更新的

  "Mod_state":"on",
  #该参数是全局规则开关，目前支持`on off`,后续增加`log` 表示仅记录

  "redis_Mod" : {"state":"on","ip":"127.0.0.1","Port" : 6379,"Password":""},
  #该参数设定redis相关参数，state：是否开启；redis的ip、端口、密码等参数
  #说明：在使用集群模式下，配置该参数，单机下无须配置使用。redis保存了config.json内容，
  #和conf_json目录下所有规则的json文件，以及拦截记录的计数（如host/method拦截计数）。

  "realIpFrom_Mod" : "on",
  #该参数是否开启从http头中取用户真实IP，适用于CDN后端等

  "ip_Mod" : "on",
  #该参数是否启用IP黑、白名单，IP是用户真实IP（http头取出，如设置）

  "host_method_Mod" : "on",
  #该参数是否启用host、method白名单

  "rewrite_Mod" : "on",
  #该参数是配置跳转使用，如set-cookie。（目前仅有set-cookie，后续增加验证码跳转）

  "app_Mod" : "on",
  #该参数是否启用用户自定义应用层规则

  "referer_Mod" : "on",
  #该参数是否启用referer过滤

  "url_Mod" : "on",
  #该参数是否启用url过滤

  "header_Mod" : "on",
  #该参数是否启用headers头过滤

  "agent_Mod" : "on",
  #该参数是否启用useragent过滤

  "cookie_Mod" : "on",
  #该参数是否启用cookie过滤

  "args_Mod" : "on",
  #该参数是否启用args过滤

  "post_Mod" : "on",
  #该参数是否启用post过滤

  "network_Mod" : "on",
  #该参数是否启用network过滤频率规则

  "replace_Mod" : "off",
  #该参数是否启用应答内容替换规则

  "debug_Mod" : true,
  #该参数是否启用日志打印（true表示启用）

  "baseDir" : "/opt/openresty/openstar/",
  #该参数表示设置OpenStar根路径（绝对路径）

  "logPath" : "/opt/openresty/openstar/logs/",
  #该参数表示配置log文件存放目录

  "jsonPath" : "/opt/openresty/openstar/conf_json/",
  #该参数表示过滤规则存放目录
  #该目录中有个host_json目录，是用于存放host过滤规则的json文件

  "htmlPath" : "/opt/openresty/openstar/index/",
  #该参数表示在app_Mod规则中一些文件、脚本存放路径

  "denyMsg" : {"state":"on","msg":403}
  #该参数表示，应用层拒绝访问时，显示的内容配置（现支持基于host配置内容/状态码）关联对应denyHost_Mod.json文件
}

  ```

## STEP 0：realIpFrom_Mod

 - 说明：
`{"101.200.122.200:5460": {"ips": ["*",""],"realipset": "x-for-f"}}`
 
 通过上面的例子，表示域名id.game.com,从ips来的直连ip，用户真实ip在x-for-f中，ips是支持二阶匹配，可以参考例子进行设置，ips为\*时，表示不区分直连ip了。

## STEP 1：ip_Mod（黑/白名单、log记录）

 - 说明：
 `{"ip":"111.206.199.61","action":"allow"}`
`{"ip":"www.game.com-111.206.199.1","action":"deny"}`
 
 上面的例子，表示ip为111.206.199.61（从http头获取，如设置）白名单
 action可以取值[allow、deny]，deny表示黑名单；第二个就表示对应host的ip黑/白名单，其他host不受影响。

## STEP 2：host\_method\_Mod（白名单）

 - 说明：
 `{"state":"on","method":[["GET","POST"],"table"],"hostname":[["id.game.com","127.0.0.1"],"table"]}`
   
  上面的例子表示，规则开启，host为id\.game\.com、127.0.0.1允许的method是GET和POST
  state：表示规则是否开启
  method：表示允许的method，参数2标识参数1是字符串、list、正则
  hostname：表示匹配的host，规则同上

  > **`"method": [["GET","POST"],"table"]`==> 表示匹配的method是GET和POST**

  > **`"method": ["^(get|post)$","jio"]` ==> 表示匹配method是正则匹配**

  > **`"hostname": ["*",""]` ==>表示匹配任意host（字符串匹配，非正则，非常快）**

  > **后面的很多规则都是使用该方式匹配的**

## STEP 3: rewrite_Mod（跳转模块）
- 说明：
```
    {
        "state": "on",
        "action": ["set-cookie","asjldisdafpopliu8909jk34jk"],
        "hostname": ["101.200.122.200",""],
        "url": ["^/rewrite$","jio"]
    }
```
上面的例子表示规则启用，host为101.200.122.200,且url匹配成功的进行302/307跳转，同时设置一个无状态cookie，名称是token。action中第二个参数是用户ip+和改参数进行md5计算的。请自行使用一个无意义字符串。防止攻击者猜测出生成算法。

## STEP 4：host_Mod
 - 说明：
 该模块是匹配对应host进行规则匹配，在conf_json/host_json/目录下，本地的基于host的匹配规则

## STEP 5：app_Mod（自定义action）
 - 说明：
 ```
{
    "state":"on",
    "action":["deny"],
    "hostname":["127.0.0.1",""],
    "url":["^/([\w]{4}\.html|deny1\.do|你好\.html)$","jio"]
}
 ```
   
  上面的例子表示规则启用，host为127.0.0.1，且url符合正则匹配的，拒绝访问

  state：规则是否启用
  action：执行动作
  
  1：deny ==> 拒绝访问
  
  2：allow ==> 允许访问
  
  3：log ==> 仅记录日志
  
  4：rehtml ==> 表示返回自定义字符串
  
  5：refile ==> 表示返回自定义文件（文件内容返回）
  
  6：relua ==> 表示返回lua执行脚本（使用dofile操作）
  
  hostname：匹配的host
  
  url：匹配的url

  > **hostname 和 url 使用上面描述过的匹配规则，参数2标记、参数1内容**

  > **详细参见项目中的demo规则，多实验、多测试就知道效果了**

  > **各种高级功能基本就靠这个模块来实现了，需要你发挥想象**

## STEP 6：referer_Mod（白名单）

 - 说明：
 `{"state":"on","url":["\\.(gif|jpg|png|jpeg|bmp|ico)$","jio"],"hostname":["127.0.0.1",""],"referer":["*",""],"action":"allow"}`
 
  上面的例子表示，host为127.0.0.1，url配置的正则成功，referer正则匹配成功就放行**【这里把一些图片等静态资源可以放到这里，因为使用OpenStar，不需要将access_by_lua_file 专门放到nginx的不同的location动态节点去，这样后续的匹配规则就不对这些静态资源进行匹配了，减少总体的匹配次数，提高效率】**，action表示执行的动作，`allow`表示规则匹配成功后，跳出后续所有规则（一般对静态资源图片），referer匹配失败就拒绝访问（白名单），防盗链为主，`next`表示匹配成功后，继续后续规则的匹配（这里主要可以设置防护站外的CSRF），referer匹配失败就拒绝访问（白名单）
  
  state：表示规则是否开启
  url：表示匹配的url
  hostname：匹配host
  referer：匹配referer
  action：匹配动作
  
  > referer的匹配是白名单，注意一下即可
  > 这些匹配都是基于上面说过的二阶匹配法

## STEP 7：url_Mod（黑、白名单）

 - 说明：
 `{"state":"on","hostname":["\*",""],"url":["\\.(css|js|flv|swf|zip|txt)$","jio"],"action":"allow"}`
   
  上面的例子表示，规则启用，任意host，url正则匹配成功后放行，不进行后续规则匹配（该场景同图片等静态资源一样进行放行，减少后续的匹配）
  state：表示规则是否开启
  hostname：表示匹配的host
  url：表示匹配url
  action：可取值[allow、deny、log]，表示匹配成功后的执行动作

  > 一般情况下，过滤完静态资源后，剩下的都是拒绝一下url的访问如.svn等一些敏感目录或文件

## STEP 8：header_Mod（黑名单）

 - 说明：
 `{"state":"on","url":["\*",""],"hostname":["\*",""],"header":["Acunetix_Aspect","\*",""]}`
 
 上面的例子表示，规则启用，匹配任意host，任意url，header中Acunetix_Aspect内容的匹配（本次匹配任意内容）这个匹配是一些扫描器过滤，该规则是wvs扫描器的特征
 state：规则是否启用
 url：匹配url
 hostname：匹配host
 header：匹配header头
  
## STEP 9：useragent_Mod （黑名单）
  - 说明：
  `{"state":"off","useragent":["HTTrack|harvest|audit|dirbuster|pangolin|nmap|sqln|-scan|hydra|Parser|libwww|BBBike|sqlmap|w3af|owasp|Nikto|fimap|havij|PycURL|zmeu|BabyKrokodil|netsparker|httperf|bench","jio"],"hostname":[["127.0.0.1:8080","127.0.0.1"],"table"]}`

  上面的例子表示，规则关闭，匹配host为127.0.0.1 和 127.0.0.1:8080 ，useragent正则匹配，匹配成功则拒绝访问，一般host设置为：`"hostname":["*",""]`表示所有（字符串匹配，非常快）
  state：规则是否启用
  hostname：匹配host
  useragent：匹配agent
 
## STEP 10：cookie_Mod（黑名单）
 - 说明：
 `{"state":"on","cookie":["\\.\\./","jio"],"hostname":["*",""],"action":"deny"}`
   
  上面的例子表示，规则启用，匹配任意host，cookies匹配正则，匹配成功则执行拒绝访问操作
  state：表示规则是否启用
  cookie：表示匹配cookie
  hostname：表示匹配host
  action：可选参数[deny、allow] 表示执行动作

  > action后续可以能增加其他action，所以预留在这，否则黑名单根本不需要action参数

## STEP 11：args_Mod（黑名单）

 - 说明：
 `{"state":"on","hostname":["*",""],"args":["\\:\\$","jio"],"action":"deny"}`
 
 上面例子表示，规则启用，匹配任意host，args参数组匹配正则，成功则执行拒绝访问动作
 state：表示规则是否启用
 hostname：表示匹配host
 args：表示匹配args参数组
 action：可选参数[deny] 表示匹配成功拒绝访问
 > action后续可以能增加其他action，所以预留在这，否则黑名单根本不需要action参数

## STEP 12：post_Mod（黑名单）
 - 说明：
 `{"state":"on","hostname":["*",""],"post":["\\$\\{","jio"],"action":"deny"}`

  上面的例子表示，规则启用，匹配任意host,post参数组匹配正则，成功则拒绝访问
  state：表示是否启用规则
  hostname：匹配host
  post：匹配post参数组
  action：可选参数[deny] 表示匹配成功后拒绝访问

  > action后续可以能增加其他action，所以预留在这，否则黑名单根本不需要action参数

## STEP 13：network_Mod（频率黑名单）
 - 说明：
 `{"state":"on","network":{"maxReqs":20,"pTime":10,"blackTime":600},"hostname":["id.game.com",""],"url":["^/2.html$","jio"]}`

  上面的例子表示，规则启用，host为id.game.com,url匹配正则，匹配成功则进行访问频率限制，在10秒内访问次数超过20次，请求的IP到IP黑名单中10分钟（60秒\*10）
  state：表示是否启用规则
  hostname：表示匹配host
  url：表示匹配url
  network：maxReqs ==> 请求次数；pTime ==> 单位时间；blacktime ==> ip黑名单时长

  > 一般情况下，cc攻击的点一个网站只有为数不多的地方是容易被攻击的点，所以设计时，考虑增加通过url细化匹配。

## STEP 14：replace_Mod（内容替换）
 - 说明：
 `{"state":"on","url":["^/$","jio"],"hostname":["passport.game.com",""],"replace_list":[["联合","","联合FUCK"],["登录","","登录POSS"],["lzcaptcha\\?key='\\s\*\\+ key","jio","lzcaptcha?keY='+key+'&keytoken=@token@'"]]}`

  上面的例子表示，规则启用，host为passport.game.com,url是正则匹配，匹配成功则进行返回内容替换
  1：将"联合"替换为"联合FUCK"；
  2：将"登录"替换为"登录POSS"；
  3：通过正则进行匹配（`ngx.re.gsub`）其中@token@表示动态替换为服务器生成的一个唯一随机字符串
  state：表示是否启用规则
  hostname：表示匹配的host
  url：表示匹配的url
  replace_list：表示替换列表，参数1 ==> 被替换内容；参数2 ==> 匹配模式（正则、字符串）如例子中前2个替换列表就是字符串匹配，使用""即可，不能没有；参数3 ==> 被替换的内容

# API相关
参考doc目录下的api.md说明

# 样例
- 参见doc下，demo.md说明


# 性能评测

**操作系统信息**
OpenStar测试服务器：

```
 微软虚机，内网测试
 
 uname -a :
 Linux dpicsvr01 4.2.0-30-generic #36-Ubuntu SMP Fri Feb 26 00:58:07 UTC 2016 x86_64 x86_64 x86_64 GNU/Linux
 
 内存：
 cat /proc/meminfo | grep MemTotal
 MemTotal:       14360276 kB// 14GB
 
 CPU型号：cat /proc/cpuinfo | grep 'model name' |uniq
 Intel(R) Xeon(R) CPU E5-2660 0 @ 2.20GHz
 
 CPU核数：cat /proc/cpuinfo | grep "cpu cores" | uniq
 4
 
 CPU个数：cat /proc/cpuinfo | grep "physical id" | uniq | wc -l
 1 
 ab：
 ab -c 1000 -n 100000 "http://10.0.0.4/test/a?a=b&c=d"
```
测试结果：
![enter description here][7]
 通过图片可以看到，关闭所有规则，做了2组测试，取最高的`8542`；
 
 启用规则（排除app，network，replace），测试结果`8388`，性能下降`1.81%`；
 
 启用规则（排除replace，app中未启用relua这个高消耗点），测试结果`7959`，性能下降`6.83%`；
 
 启用规则（排除useragent，ab工具默认被拦截了，第二个测试就不完全了。）测试结果`7116`，性能下降`16%`；
 
 总的来说，启用规则后，性能损失可以接受，根据自身的业务进行调整，还可以有所优化。
 
# 变更历史

## **next 1.x 增加app_Mod，丰富allow动作，支持的参数 and 增加token和IP绑定功能 **

## 1.3 更新跳转功能，可配置进行set-cookie操作
可以配置某一个或者多个url使用跳转set-cookie操作。cookie是无状态的。

## 1.2 更新支持拦截外部的csrf
在referer_Mod处，增加action，`allow`表示允许且后续的规则不用在匹配（一般是静态资源如图片/js/css等），`next`表示白名单匹配成功后，会继续后面的规则匹配（这里就用于拦截外部的CSRF）增加`next`是因为原来代码中，若配置了防护站外的CSRF，后续的规则会bypass,所以增加的，这样就不会出现一些绕过问题。
**后续的action理论上都支持该语法**

## 1.1 增加app_Mod,丰富allow动作（ip）
网站的某个目录进行IP白名单的访问控制（后台、phpmyadmin等）

## 0.9 - 1.0 修改了大量全局函数

在学习完[OpenResty最佳实践][5]后，代码太不专业，修改了大量全局变量、函数

## 0.8 优化一下算法

原来args是遍历每个参数在连接起来，感觉性能有时有点瓶颈，就使用新api取出url中的所有参数，经过测试效果要比原来好很多。

## 0.7 增加集群版本

- 当时大约有2-4台OpenStar服务器用于安全防护，通过脚本进行统一管理的，没有进行真正的统一管理，所以抽空的时候把redis用上。

## 0.6 增加API相关操作

- 因为是个蹩脚的程序员（没办法，搞安全的现在都被逼的写代码了；感谢春哥，我在写的过程中非常的快乐，所以就把项目叫做OpenStar[开心]，请勿见笑了）、前端界面我迟迟没有想好，所以先把一下操作的API封装了，也满足当时公司脚本化需求。

## 0.4-0.5 增加配置文件操作

- 刚开始都是写在lua代码中，随着功能增加，决定通过配置文件进行操作，所有就使用json方式进行定义配置文件。

## 0.3 增加waf防护模块

- 随着cc防护成功后，我陆续增加了waf相关的功能，规则参考了[modsecurity][6]、[loveshell][4]防护模块、以及互联网搜集的一些过滤点

## 0.2 CC防护应用层版

- 通过网络层+应用层的防护后，我后续增加了应用层的安全防护，如应用层set cookie、url跳转、js跳转等这样应用层的防护模块

## 0.1 CC防护版

- 当时是为了解决公司的CC攻击，由于一些硬件抗D设备在新的网络环境下（有CDN网络下）无法获取用户真实IP头，我才动手将第一个版本完成，当时功能就是有通过自定义HTTP头获取用户真实ip进行访问频率的限制。（OpenStar可以根据某个url进行频率限制，不仅仅是整个网站的[排除静态文件，如设置了referer\_Mod 或者 url\_Mod 中资源的allow操作]）

# 关于

- 关于该项目前面其实已经说了不少，从无到有基本都说了，强调下，感谢春哥，[loveshell][4]！！！
- 关于我：从事安全、架构相关工作。
- Copyright and License
GPL（GNU General Public License）
Copyright (C) 2011-2016, by zj 


  [1]: https://github.com/agentzh
  [2]: http://openresty.org/cn/
  [3]: ./doc/Openstar.jpg "OpenStar.jpg"
  [4]: https://github.com/loveshell/ngx_lua_waf
  [5]: https://moonbingbing.gitbooks.io/openresty-best-practices/content/index.html
  [6]: http://www.modsecurity.org/
  [7]: ./doc/test.png "test.png"
