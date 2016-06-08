---
title: OpenStar(开心)说明
tags: OpenResty,OpenStar,waf+,云waf,nginx lua
grammar_cjkRuby: true

---


欢迎使用 **{OpenStar}(WAF+)**，该项目是从实际需求中产生，用于解决当时实际出现的问题，经过多次的版本迭代到今天，实属不易。感谢**春哥**，该项目是解决工作的实际问题一点一滴积累的经验，(==多多指导==) 特别感谢[春哥][1]为我们做好的一件神器（**[OpenResty][2]**）
**代码写的比较好理解，至于代码是否优雅 呵呵~**

# 概览


----------


**OpenStar**是一个基于[OpenResty][2]的，高性能web平台，不仅仅包含了传统WAF的功能模块，还相应增加了其他灵活、友好、实用的功能，是增强的WAF、WEB扩展、CC防护的集合。
# WAF防护


----------


在**OpenStar**中的WAF防护模块，采用传统的黑白名单、正则过滤的方式（*有人会问现在不是流行自主学习么；正则、黑白名单会有盲点、会被绕过......*）。这里我简单说明一下，自主分析学习引擎是我们的日志分析引擎做的，这里是高性能、高并发的点，就用简单粗暴的方法解决，根据业务实际调整好防护策略，可以解决绝大多数WEB安全1.0和WEB安全2.0类型的漏洞（90%+的问题）。
WAF	防护从header,args,post,访问频率等，分层进行按顺序防护，详细在后面的功能会详细说明

 - **WEB安全1.0**
   在1.0时代下，攻击是通过服务器漏洞（IIS6溢出等）、WEB应用漏洞（SQL注入、文件上传、命令执行、文件包含等）属于服务器类的攻击，该类型漏洞虽然经历了这么多年，很遗憾，此类漏洞还是存在，并且重复在犯相同的错误。

 - **WEB安全2.0**
   随着社交网络的兴起，原来不被重视的XSS、CSRF等漏洞逐渐进入人们的视野，那么在2.0时代，漏洞利用的思想将更重要，发挥你的想象，可以有太多可能。

 - **WEB安全3.0**
   同开发设计模式类似（界面、业务逻辑、数据），3.0将关注应用本身的业务逻辑和数据安全，如密码修改绕过、二级密码绕过、支付类漏洞、刷钱等类型的漏洞，故注重的是产品本身的业务安全、数据安全。
   
   > `安全不仅仅是在技术层面、还应该在行政管理层面、物理层面去做好安全的防护，才能提供最大限度的保护。`
   > 安全行业多年的从业经验：人，才是最大的威胁；无论是外部、内部、无心、有意过失。（没有丑女人、只有懒女人）我想可以套用在此处，纯属个人见解。
 
# CC/采集防护
什么是**CC攻击**，简单的说一下，就是用较少的代价恶意请求web（应用）中的重资源消耗点（CPU/IO/数据库等等）从而达到拒绝服务的目的；**数据采集**，就是内容抓取了，简单这么理解吧
> `非官方学术类的解释，先将就理解下`
**关于本文对CC攻击的分析和相关的防护算法，都是我在实战中分析总结，并形成自己的方法论，不足之处、欢迎指正。**

## 攻击类型
 - 行为（GET、POST等）
  目前主要还是这2中method攻击为主，其他的基本没有，因为比较互联网上的web应用也都是这2中居多。
 - 被攻击的点
     1： 用户可直接访问的URL（搜索、重CPU、IO、数据库的点）
     
     2：嵌入的URL（验证码、ajax接口等）
     
     3：面向非浏览器的接口（一些API、WEBservice等）
     
 -  基于特定web服务、语言等的特定攻击（慢速攻击、PHP-dos等） 
 
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

1：用户可直接访问的url

第一阶段（应用层）：js跳转、验证码、flash策略（拖动识别等）

第一阶段（网络层）：访问频率限制，超出阀值仅黑名单一段时间
（这种是最好防的）

2：嵌入的url（ajax校验点、图片验证码）

第一阶段（应用层）：载入被攻击的url页面，重写页面，使用js方操作链接被攻击的url。js随机在url尾巴增加有一定规则的校验串，服务端对串进行静态正则校验。

第一阶段（网络层）：访问频率限制，超出阀值仅黑名单一段时间

第二阶段（应用层）：校验串使用服务端生成的token，进行严格服务器token验证检查

第二阶段（网络层+应用层）：用户ip在http头中，需要从http头取ip，在进行频率限制
（其实做好了，这一层的防护，基本不用进入第三阶段的应用层防护了）

第三阶段（应用层）：js增加浏览器识别（不同agent匹配不同js识别代码）、鼠标轨迹验证、键盘鼠标事件验证等js增加验证后，在进行校验串生成。

> 应用层的防护是在网络层+扩展的网络层防护效果不佳时使用，一般情况基本用的不多，因为在OpenStar的防护下，极少数情况下，需要第三阶段防护。在防页面抓取时，发挥你的想象（js是个好帮手，善用）使用OpenStar就可以帮你快速实现；当然使用flash防抓取效果更好（不够灵活）。

# 目录

后续更新！~

# 下载

wget

git clone 

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

# 使用

## 配置规则

一般情况下匹配某一规则由2个参数组成，第二个参数标识第一个参数类型
hostname：`["*",""]` 表示匹配所有域名（使用字符串匹配，非正则，非常快）
hostname：`["*\\.game\\.com","jio"]` 表示使用正则匹配host（**ngx.re.find($host,参数1，参数2)**）
hostname：`[["127.0.0.1","127.0.0.1:8080"],"table"]` ·表示匹配参数1列表中所有host

## 执行流程

![enter description here][3]

 - init阶段
 
 a：首先加载本地的config.json配置文件，将相关配置读取到dict中
 
 b：定义全局函数，日志记录、token生成等。
 - rewrite阶段
 暂无操作（这个预留跳转用的）
 - access阶段（自上到下的执行流程，规则列表也是自上到下按循序执行的）
 
 0：realIpFrom_Mod ==> 获取用户真实IP（从HTTP头获取，如设置）
 
 1：ip_Mod ==> 请求ip的黑、白名单过滤
 
 2：host\_method\_Mod ==> host和method过滤（白名单）
 
 3：app_Mod ==> 用户自定义应用层过滤
 
 4：referer_Mod ==> referer过滤（白名单）
 
 5：url_Mod ==> url过滤（黑、白名单）
 
 6：header_Mod ==> header过滤（黑名单）
 
 7：useragent_Mod ==> useragent过滤（黑名单）
 
 8：cookie_Mod ==> cookie过滤（黑名单）
 
 9：args_Mod ==> args参数过滤（黑名单）
 
 10：post_Mod ==> post参数过滤（黑名单）
 
 11：network_Mod ==> 应用层网络频率限制（频率黑名单）
 
 - body阶段
 
 12：replace_Mod ==> 内容替换规则（动态进行内容替换，性能消耗较高慎用，可以的话用app_Mod中rehtml、refile这2个自定义action）
 
## 主配置

  config.json文件进行配置，主要是一些参数开关、目录设置
  注：以下表示法，"on"表示开启，"off"表示关闭。
  + redis_Mod
  该参数设定redis相关参数，state：是否开启；redis的ip、端口、密码等参数
  说明：在使用集群模式下，配置该参数，单机下无须配置使用。redis保存了config.json内容，和conf_json目录下所有规则的json文件，以及拦截记录的计数（如host/method拦截计数）。
  + realIpFrom_Mod 
  该参数是否开启从http头中取用户真实IP，适用于CDN后端等
  + ip_Mod
  该参数是否启用IP黑、白名单，IP是用户真实IP（http头取出，如设置）
  + host\_method\_Mod 
  该参数是否启用HOST、METHOD白名单
  + app_Mod 
  该参数是否启用用户自定义应用层规则
  + referer_Mod 
  该参数是否启用REFERER过滤白名单
  + url_Mod 
  该参数是否启用URL过滤黑、白名单
  + header_Mod 
  该参数是否启用HEADER头过滤黑名单
  + agent_Mod 
  该参数是否启用USERAGENT过滤黑名单
  + cookie_Mod 
  该参数是否启用COOKIE过滤黑名单
  + args_Mod 
  该参数是否启用ARGS过滤黑名单
  + post_Mod 
  该参数是否启用POST过滤黑名单
  + network_Mod 
  该参数是否启用NETWORK过滤频率黑名单规则
  + replace_Mod 
  该参数是否启用body内容替换规则
  + debug_Mod 
  该参数是否启用日志打印（true表示启用）
  + baseDir 
  该参数表示设置OpenStar根路径（绝对路径）
  + logPath 
  该参数表示配置log文件存放目录
  + jsonPath 
  该参数表示过滤规则存放目录
  + htmlPath 
  该参数表示在app_Mod规则中一些文件、脚本存放路径
  + sayHtml
  该参数表示，应用层拒绝访问时，显示的内容配置

## STEP 0：realIpFrom_Mod

 - 说明：
`{"id.game.com":{"ips":["111.206.199.57"],"realipset":"CDN-R-IP"}}`
 
 通过上面的例子，表示域名id.game.com,从ips来的直连ip，用户真实ip在CDN-R-IP中，ips是list，可以写多个，后续会增加使用正则或者ip段来匹配。（因为当时场景中ip没有多少，所有就用了list，）可以参考例子进行设置，ips为\*时，表示不区分直连ip了。

## STEP 1：ip_Mod（黑、白名单）

 - 说明：
 `{"ip":"111.206.199.61","action":"allow"}`
 
 上面的例子，表示ip为111.206.199.61（从http头获取，如设置）白名单
 action可以取值[allow、deny]，deny表示黑名单

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


## STEP 3：app_Mod（自定义action）
 - 说明：
 `{"state":"on","action":["deny"],"hostname":["127.0.0.1",""],"url":["^/([\\w]{4}\\.html|deny1\\.do|你好\\.html)$","jio"]}`
   
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

## STEP 4：referer_Mod（白名单）

 - 说明：
 `{"state":"on","url":["\\.(gif|jpg|png|jpeg|bmp|ico)$","jio"],"hostname":["127.0.0.1",""],"referer":["*",""],"action":"allow"}`
 
  上面的例子表示，host为127.0.0.1，url配置的正则成功，referer正则匹配成功就放行**【这里把一些图片等静态资源可以放到这里，因为使用OpenStar，不需要将access_by_lua_file 专门放到nginx的不同的location动态节点去，这样后续的匹配规则就不对这些静态资源进行匹配了，减少总体的匹配次数，提高效率】**，action表示执行的动作，`allow`表示规则匹配成功后，跳出后续所有规则（一般对静态资源图片），referer匹配失败就拒绝访问（白名单），防盗链为主，`next`表示匹配成功后，继续后续规则的匹配（这里主要可以设置防护站外的CSRF），referer匹配失败就拒绝访问（白名单）
  
  state：表示规则是否开启
  url：表示匹配的url
  hostname：匹配host
  referer：匹配referer
  action：匹配动作
  
  > referer的匹配是白名单，注意一下即可
  > 这些匹配都是基于上面说过的2阶匹配法

## STEP 5：url_Mod（黑、白名单）

 - 说明：
 `{"state":"on","hostname":["\*",""],"url":["\\.(css|js|flv|swf|zip|txt)$","jio"],"action":"allow"}`
   
  上面的例子表示，规则启用，任意host，url正则匹配成功后放行，不进行后续规则匹配（该场景同图片等静态资源一样进行放行，减少后续的匹配）
  state：表示规则是否开启
  hostname：表示匹配的host
  url：表示匹配url
  action：可取值[allow、deny]，表示匹配成功后的执行动作

  > 一般情况下，过滤完静态资源后，剩下的都是拒绝一下url的访问如.svn等一些敏感目录或文件

## STEP 6：header_Mod（黑名单）

 - 说明：
 `{"state":"on","url":["\*",""],"hostname":["\*",""],"header":["Acunetix_Aspect","\*",""]}`
 
 上面的例子表示，规则启用，匹配任意host，任意url，header中Acunetix_Aspect内容的匹配（本次匹配任意内容）这个匹配是一些扫描器过滤，该规则是wvs扫描器的特征
 state：规则是否启用
 url：匹配url
 hostname：匹配host
 header：匹配header头
  
## STEP 7：useragent_Mod （黑名单）
  - 说明：
  `{"state":"off","useragent":["HTTrack|harvest|audit|dirbuster|pangolin|nmap|sqln|-scan|hydra|Parser|libwww|BBBike|sqlmap|w3af|owasp|Nikto|fimap|havij|PycURL|zmeu|BabyKrokodil|netsparker|httperf|bench","jio"],"hostname":[["127.0.0.1:8080","127.0.0.1"],"table"]}`

  上面的例子表示，规则关闭，匹配host为127.0.0.1 和 127.0.0.1:8080 ，useragent正则匹配，匹配成功则拒绝访问，一般host设置为：`"hostname":["*",""]`表示所有（字符串匹配，非常快）
  state：规则是否启用
  hostname：匹配host
  useragent：匹配agent


 
## STEP 8：cookie_Mod（黑名单）
 - 说明：
 `{"state":"on","cookie":["\\.\\./","jio"],"hostname":["*",""],"action":"deny"}`
   
  上面的例子表示，规则启用，匹配任意host，cookies匹配正则，匹配成功则执行拒绝访问操作
  state：表示规则是否启用
  cookie：表示匹配cookie
  hostname：表示匹配host
  action：可选参数[deny、allow] 表示执行动作

  > action后续可以能增加其他action，所以预留在这，否则黑名单根本不需要action参数

## STEP 9：args_Mod（黑名单）

 - 说明：
 `{"state":"on","hostname":["*",""],"args":["\\:\\$","jio"],"action":"deny"}`
 
 上面例子表示，规则启用，匹配任意host，args参数组匹配正则，成功则执行拒绝访问动作
 state：表示规则是否启用
 hostname：表示匹配host
 args：表示匹配args参数组
 action：可选参数[deny] 表示匹配成功拒绝访问
 > action后续可以能增加其他action，所以预留在这，否则黑名单根本不需要action参数

## STEP 10：post_Mod（黑名单）
 - 说明：
 `{"state":"on","hostname":["*",""],"post":["\\$\\{","jio"],"action":"deny"}`

  上面的例子表示，规则启用，匹配任意host,post参数组匹配正则，成功则拒绝访问
  state：表示是否启用规则
  hostname：匹配host
  post：匹配post参数组
  action：可选参数[deny] 表示匹配成功后拒绝访问

  > action后续可以能增加其他action，所以预留在这，否则黑名单根本不需要action参数

## STEP 11：network_Mod（频率黑名单）
 - 说明：
 `{"state":"on","network":{"maxReqs":20,"pTime":10,"blackTime":600},"hostname":["id.game.com",""],"url":["^/2.html$","jio"]}`

  上面的例子表示，规则启用，host为id.game.com,url匹配正则，匹配成功则进行访问频率限制，在10秒内访问次数超过20次，请求的IP到IP黑名单中10分钟（60秒\*10）
  state：表示是否启用规则
  hostname：表示匹配host
  url：表示匹配url
  network：maxReqs ==> 请求次数；pTime ==> 单位时间；blacktime ==> ip黑名单时长

  > 一般情况下，cc攻击的点一个网站只有为数不多的地方是容易被攻击的点，所以设计时，考虑增加通过url细化匹配。

## STEP 12：replace_Mod（内容替换）
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
>所有api相关都没有进行严格参数限制，后续有时间在添加了，请谨慎操作

 - debug.lua
 对GET/POST进行原样返回，以及一些扩展信息，有时方便我测试使用。
 
 - ip_dict.lua
  api接口对dict进行操作的封装。可操作的dict（count_dict、config_dict、ip_dict、limit_ip_dict）
**谨慎操作，未做严格校验**

add ：**仅对ip_dict有效**，增加IP黑、白名单的。

`http://*/api/ip_dict?action=add&dict=ip_dict&key=192.168.2.5&value=allow[deny]&time=60`
value默认拒绝，time默认永久，上述就是向ngx.share.ip_dict增加信息，把该ip增加到白名单，时长是60秒

del：表示删除操作

`http://*/api/ip_dict?action=del&dict=ip_dict&key=192.168.2.56`
key=all_key时，表示删除所有，其余情况删除指定key

set：**仅对ip_dict有效**、表示修改ip黑白名单。

`http://*/api/ip_dict?aciton=set&dict=ip_dict&key=192.168.2.56&value=deny`
value默认就是deny。

get：表示查询内容

`http://*/api/ip_dict?action=get&dict=ip_dict&key=192.168.2.58`
key=count_key时，表示查询该dict中key的总个数；key=all_key时，表示显示所有key和value（谨慎使用）；key=无参数，表示查询1024个key和value；key=$其他值时，表示仅查询该key的值。

>关于返回信息，大家自行测试、看代码吧。

- redis.lua【需要更新】

api接口对redis进行相关操作

set：表示将传递的数据存放到redis上

`http://*/api/redis?action=set&key=aaa&value=it is a string`
上面的操作就是将key(aaa)存放到redis上，值是"it is a string"（redis就是config.json中配置的）,该功能暂和业务无关。

get：表示通过key查询redis中的值

`http://*/api/redis?action=get&key=aaa`
key=config\_dict/count\_dict时，返回的value进行json转换后显示。（redis作用就是保存这2个dict）

push：表示将config_dict或者count_dict存放到redis上

`http://*/api/redis?action=push&key=config_dict`
上面的操作就是将config\_dict转成json字符串后存放到redis,key=count\_dict表示把count\_dict保存到redis。（覆盖保存，这里的count\_dict计数的汇总，我们这边是python做的，这些接口都是我们的python程序调用使用的）

- config.lua
api接口对配置规则（主配置、mod规则配置）进行保存到本地json文件中

`http://*/api/config?action=save&name=app_Mod&debug=no`
上面的操作表示将app\_Mod（全局table）规则保存到相应文件夹下，当`debug`为`no`时，则覆盖原配置文件，否则会添加`_bak`标记

`http://*/api/config?action=load`
上面的操作表示，重新载入所有规则文件

- table.lua【暂停使用】
>对规则操作实时生效的

- time.lua
api对ngx对时间操作相关的调试，可以不用管

- test.lua【暂停使用】
api对全局规则进行测试调试使用的，批量添加垃圾规则，用于测试规则数量对性能影响的，对13个Mod调试使用的

`http://*/api/test?mod=ip_Mod&count=99`
这个表示对ip_Mod增加99个随机信息，其他的各类Mod大家看代码吧，特别是做调试的时候，最后的一个条目需要根据自己的情况去写

- token.lua
api对token进行相关操作的，本来已经有了一个对dict相关操作的api，为了区分下， 我分离了。

get：对token_list进行查询操作

`http://*/api/token?action=get&key=key_dog`
该请求就是查询token\_list这个dict中key为key\_dog的值，key=count\_key时，表示查询该token\_lis中key的总个数；key=all\_key时，表示显示所有key和value（谨慎使用）；key=无参数，表示查询1024个key和value

set：对token_list进行添加操作

`http://*/api/token?action=set&key=abc&value=iooppp`
该请求就是设置key=abc，value=iooppp，value没有传参数将自动生成一个，value在token_list中存在也将自动生成一个

# 样例
- 参见项目自带规则demo，后续我将把自带规则每个都解释、说明一下，以及常用的功能实现说明一下，方便大家理解并使用

## host和method规则配置
在一些场景中我们需要限制准入的host和允许的method（CDN&&前端服务器）
如我们仅允许域名为\*.test.com，method仅允许get和post；那么我们就配置host_method_Mod.json文件
```
 {
        "state": "on",
        "method": [["GET","POST"],"table"],
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
        "state": "off",
        "method": ["GET",""],
        "hostname": ["*",""]
    }
]
```
配置规则就是这样，请多测试几次，就熟悉了，也是比较简单；关于这个jio的意思，其实就是`ngx.re.find(参数1,参数2,"jio")` 这里使用，区分大小写就是：` jo`；具体的一些参数请参考http://blog.csdn.net/weiyuefei/article/details/38439017

## 获取用户真实ip设置
在一些应用场景下，需要从http头的某一字段中获取用户真实IP，一般默认用`X-Forwarded-For` 或者 `X-Real-IP`，但是有时会被黑客伪装（没有设置remote Ip源），以及一些CDN厂商自定义的http头（CDN-SOURCE-IP），故就需要我们配置那个host，从哪些remote ip 来的，取http头中哪个标记字段
如host是id.test.com从192.168.10.6-8来的ip，从http头my-ip-real中获取；那么就需要配置realIpFrom_Mod.json文件
```
{
"id.test.com": {
        "ips": [
            "192.168.10.8",
            "192.168.10.7",
            "192.168.10.6"
        ],
        "realipset": "my-ip-real"
    }
}
如果要配置是所有来源IP
{
"id.test.com": {
        "ips":"*",
        "realipset": "my-ip-real"
    }
}
```
说明一下，目前host仅允许写单个，目前不支持通过正则或者list来匹配host，ips是一个list，所以不要忘记`[]`了。

## 配置自定义规则
`deny` ：就是应用层拒绝访问了，如果一些url我们不需要外部可以访问(白名单IP不受该限制)。
```
{
        "state": "on",
        "action": ["deny"],
        "hostname": ["127.0.0.1",""],
        "url": ["^/([\\w]{4}\\.html|deny\\.do|你好\\.html)$","jio"]
}
```
基础匹配hostname，url，host为`127.0.0.1`，url进行正则匹配，如果匹配成功，就执行`action`操作，这里就是拒绝访问。

`rehtml`：这个动作就是返回字符串
```
{
        "state": "on",
        "action": ["rehtml"],
        "rehtml": "hi~!",
        "hostname": ["127.0.0.1",""],
        "url": ["^/rehtml$","jio"]
    }
```
这个也比较好理解，host是`127.0.0.1`，url通过正则匹配，匹配成功就把`rehtml`中的内容直接返回了，应用场景也是比较多的。

`refile`：这个动作就是返回`./index`目录下文件的内容了，看个例子吧
```
{
        "state": "on",
        "action": ["reflie"],
        "reflie": "2.txt",
        "hostname": ["127.0.0.1",""],
        "url": ["^/refile$","jio"]
    }
```

`relua`：这个动作就是执行lua脚本文件（dofile实现）
```
{
        "state": "on",
        "action": ["relua"],
        "relua":"1.lua",
        "hostname": ["*",""],
        "url": ["*",""]
    }
```
这个匹配规则，host是所有的，url也是所有，匹配成功后执行`./index`目录下的1.lua文件
文件代码：
```

-----  自定义lua脚本 by zj -----
local remoteIp = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local host = ngx.req.get_headers()["Host"] or "unknownhost"
local method = ngx.var.request_method
local url = ngx.unescape_uri(ngx.var.uri)
local referer = headers["referer"] or "unknownreferer"
local agent = headers["user_agent"] or "unknownagent"	
local request_url = ngx.unescape_uri(ngx.var.request_uri)


local config_dict = ngx.shared.config_dict

--- config_is_on()
local function config_is_on(config_arg)	
	if config_dict:get(config_arg) == "on" then
		return true
	end
end

-- 传入 (host  连接IP  http头)
local function loc_getRealIp(host,remoteIP,headers)
	if config_is_on("realIpFrom_Mod") then
		local realipfrom = realIpFrom_Mod or {}
		local ipfromset = realipfrom[host]		
		if type(ipfromset) ~= "table" then return remoteIP end
		if ipfromset.ips == "" then
			local ip = headers[ipfromset.realipset]
			if ip then
				if type(ip) == "table" then ip = ip[1] end  --- http头中又多个取第一个
			else
				ip = remoteIP
			end
			return ip
		else
			for i,v in ipairs(ipfromset.ips) do
				if v == remoteIP then
					local ip = headers[ipfromset.realipset]
					if ip then
						if type(ip) == "table" then ip = ip[1] end  --- http头中又多个取第一个
					else
						ip = remoteIP
					end
					return ip
				end
			end
			return remoteIP
		end
	end
end
local ip = loc_getRealIp(host,remoteIp,headers)


--- remath(str,re_str,options)
local function remath(str,re_str,options)
	if str == nil then return false end
	if options == "" then
		if str == re_str or re_str == "*" then
			return true
		end
	elseif options == "table" then
		for i,v in ipairs(re_str) do
			if v == str then
				return true
			end
		end
	else
		local from, to = ngx.re.find(str, re_str, options)
	    if from ~= nil then
	    	return true
	    end
	end
end

--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if remath(host,_host[1],_host[2]) and remath(url,_url[1],_url[2]) then
		return true
	end
end

--- 
local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local tb_do = {
				host={"*",""},
				url={[[/api/time]],""}
			}


if host_url_remath(tb_do.host,tb_do.url) then
	ngx.say("ABC.ABC IS ABC")
	return "break"   --- break 表示跳出for循环，且直接返回给客户端，不进行后面的规则匹配了
else
	return  ---- 否则继续for循环 继续规则判断
end
```
如果有一些复杂的可以直接使用lua脚本去实现，这个脚本的意思是匹配任意host，url是`/api/time`的，匹配成功后直接返回内容`ABC.ABC IS ABC`，注意一下`return` 看注释。(自定义的lua脚本可以参考这个，比较简单)

`log`：这个就表示仅仅记录一些log（log保存的路径就是在config.json里面，文件名是app_log.log）
```
{
        "state": "on",
        "action": ["log"],
        "hostname": ["127.0.0.1",""],
        "url": ["^/log$","jio"]
    }
```
比较好理解，注意hostname和url的匹配方式（二阶匹配）

`allow`：动作白名单，如果基本的hostname和url匹配成功后，后面的规则匹配失败就拒绝访问了
```
{
        "state": "on",
        "action": ["allow"],
        "allow":["args","keyby","^[\\w]{6}$"],
        "hostname": [["101.200.122.200","127.0.0.1"],"table"],
        "url": ["^/api/time$","jio"]
    }
```
基础匹配host和url，匹配成功后，`allow`值中，第一个是`args`，表示匹配的是args参数，参数名是第二个`keyby`，匹配规则是第三个`^[\\w]{6}$`，这个正则也是比较好理解：6个任意字符串即可，这里是我在设计防护CC时用到的客户端防护，对`args`的参数进行静态正则的检查，在看下面这个是使用动态token的检查，`token`是由服务器生成的，判断token是否合法即可。
```
{
        "state": "on",
        "action": ["allow"],
        "allow":["args","keytoken","@token@"],
        "hostname": ["101.200.122.200",""],
        "url": ["/api/debug",""]
    }
```
这个`args`参数的动态检查和静态检查基本一样，语法不一样的就是`allow`参数3是固定的`@token@`，不在是正则表达式，接下来在说一个是`ip`的检查，**这个场景也是比较多，就是对某个文件夹（url路径/程序后台路径/phpmyadmin 等这样管理后台，通过IP访问控制）这样可以精细到文件夹的IP访问控制（非常实用的功能）**。
```
{
        "state": "on",
        "action": ["allow"],
        "allow":["ip",["106.37.236.170","1.1.1.1"],"table"],
        "hostname": [["101.200.122.200","127.0.0.1"],"table"],
        "url": ["/api/.*","jio"]
    }
```
这个配置就表示，访问`/api/.*`这些目录的只有`ip`为`1.1.1.1`和`106.37.236.170`，是不是很简单，对目录进行明细的IP访问控制。

## 配置referer过滤
在该模块下，一些防盗链，站外CSRF等都是在这里设置，如我需要设置图片仅允许本站进行引用。
```
{
        "state": "on",
        "url": [
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
```
上面的配置就是`www.test.com`这个网站的图片资源仅允许`referer`是`*.test.com`来的，如果`referer`不对就拒绝访问了，如果`action`是`allow`那么匹配到的这些url将不会进行后面的规则匹配，这样就减少规则匹配，提高效率
在看一个例子，就是防止站外的CSRF了(浏览器发起的)。
```
{
        "state": "on",
        "url": [
            "^/abc.do$",
            "jio"
        ],
        "hostname": [
            "pass.test.com"
            ""
        ],
        "referer": [
            "^.*/(www\\.test\\.com|www3\\.test\\.com)$",
            "jio"
        ],
        "action":"next"

    }
```
上面的这个配置就是url`abc.do`的请求referer来源进行了限制，否则就拒绝访问，且`action`是`next`就表示，后续的规则匹配继续，1.2版本之前会bypass的。现在不会了。

## 配置url过滤
url的过滤当然就是一些敏感文件目录啥的过滤了，看个例子吧
```
{
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "url": [
            "\\.(svn|git|htaccess|bash_history)",
            "jio"
        ],
        "action": "deny"
}
```
首先看`hostname`,这里匹配的是所有，`url`就是一些敏感文件、目录了，动作`action`就是拒绝了。
在说一个动作是`allow`的，这个场景就是一些静态资源，这些匹配后，不进行后续的规则匹配，总体是减少匹配的次数，提高效率的，因为不需要在不同的`location`中单独去引用LUA文件了，也是非常实用的功能
```
{
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "url": [
            "\\.(css|js|flv|swf|zip|txt)$",
            "jio"
        ],
        "action": "allow"
}
```
上面的例子也是比较好理解的，不做解释了。
**这里的规则是[loveshell][4]总结的，后面的多数规则都是直接用loveshell的**

## 配置header过滤
这里`header`过滤了，比如一些扫描器特征，wvs的`header`在默认是有一个标记的`Acunetix_Aspect`,来个例子
```
{
    "state": "on",
    "url": ["*",""],
    "hostname": ["*",""],
    "header": ["Acunetix_Aspect","*",""]        
}
```
这个例子就是拦截wvs扫描器的。

>占位符，后续会更新一些慢速攻击的特征

## 配置useragent过滤
`useragent`的过滤，一些脚本语言带的`agent`默认都给过滤了（ab 也过滤了）。
```
{
    "state": "on",
    "useragent": [
        "HTTrack|harvest|audit|dirbuster|pangolin|nmap|sqln|-scan|hydra|Parser|libwww|BBBike|sqlmap|w3af|owasp|Nikto|fimap|havij|PycURL|zmeu|BabyKrokodil|netsparker|httperf|bench",
        "jio"
    ],
    "hostname": [
        "*",
        ""
    ]
}
```

## 配置cookie过滤
关于`cookie`过滤，一般就是SQL注入等问题。
```
{
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "cookie": ["select.+(from|limit)","jio"],
        "action": "deny"
}
```
关于SQL注入需要根据自己的业务进行相应的调整，这样就可以更全面的防护。

## 配置get/post参数过滤
`get/post`参数的过滤就是SQL/XSS等问题（就是args_Mod.json和post_Mod.json）。参数污染是绕过不了的。

参考http://www.freebuf.com/articles/web/36683.html；
参考http://drops.wooyun.org/tips/132

一些waf的bypass技巧。我们根据自己的业务进行调整即可。
**这个一定要根据实际情况配置**
```
{
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "args": ["sleep\\((\\s*)(\\d*)(\\s*)\\)","jio"],
        "action": "deny"
}
// -- XSS
{
        "state": "on",
        "hostname": [
            "*",
            ""
        ],
        "args": ["\\<(iframe|script|body|img|layer|div|meta|style|base|object|input)","jio"],
        "action": "deny"
}
```
这些规则默认集成的[loveshell][4]，一定要根据自己的业务场景进行调整。抓过菜刀连接的数据包的人应该清楚，这里我们也可以进行过滤。

## 配置网络访问频率限制
关于访问频率的限制，支持对明细`url`的单独限速，当然也可以是整站的频率限制。
```
-- 单个URL的频率限制
-- 因为一个网站一般情况下容易被CC的点就那么几个
{
    "state": "on",
    "network":{"maxReqs":10,"pTime":10,"blackTime":600},
    "hostname": [["101.200.122.200","127.0.0.1"],"table"],
    "url": ["/api/time",""]
}
-- 限制整个网站的（范围大的一定要放下面）
{
    "state": "on",
    "network":{"maxReqs":30,"pTime":10,"blackTime":600},
    "hostname": [["101.200.122.200","127.0.0.1"],"table"],
    "url": ["*",""]
}
-- 限制ip的不区分host和url
{
    "state": "on",
    "network":{"maxReqs":100,"pTime":10,"blackTime":600},
    "hostname": ["*",""],
    "url": ["*",""]
}
```
一定要根据自己的情况进行配置！！！

## 配置返回内容的替换规则
这个功能模块，主要是对返回内容的修改，根据自己情况使用吧。
```
{
        "state": "on",
        "url": ["^/api/ip_dict$","jio"],
        "hostname": ["101.200.122.200",""],
        "replace_list":
            [
             ["deny","","denyFUCK"],
             ["allow","","allowPASS"],
             ["lzcaptcha\\?key='\\s*\\+ key","jio","lzcaptcha?keY='+key+'&keytoken=@token@'"]
            ]
}
```
这里就不在解释了，注意的是`replace_list`这个是个内容替换的list，`@token@`就是动态的替换成服务器生成的`token`了。

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

## **next 1.x 增加app_Mod，丰富allow动作，支持的参数...**

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
  [3]: ./OpenStar.png "OpenStar.png"
  [4]: https://github.com/loveshell/ngx_lua_waf
  [5]: https://moonbingbing.gitbooks.io/openresty-best-practices/content/index.html
  [6]: http://www.modsecurity.org/
  [7]: ./test.png "test.png"
