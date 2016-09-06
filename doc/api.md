
API相关介绍：

# 基本使用
相关API在单独的server中，即ip:5460,那么对于接口就是`http://ip:5460/api/xxx`

# 模块介绍

 - base
 表示基本配置，参考readme.md的说明即可

 - realIpFrom_Mod
 表示配置设置从http头中获取用户真实IP

 - ip_Mod
 ip过滤模块

 - host_method_Mod
 host && method 过滤模块

 - rewrite_Mod
 跳转规则模块 set-cookie

 - host_Mod
 对应host执行的规则过滤（url,referer,useragent,network）

 - app_Mod
 自定义应用规则模块

 - referer_Mod
 referer过滤模块

 - url_Mod
 url过滤模块

 - header_Mod
 header过滤模块

 - useragent_Mod
 useragent过滤模块

 - cookie_Mod
 cookie过滤模块

 - args_Mod
 get参数过滤模块

 - post_Mod
 post参数过滤模块

 - network_Mod
 网络层连接频率限制模块

 - replace_Mod
 返回内容替换模块

 - host_Mod
 应用层拒绝访问时，显示的内容配置

# /api/config
配置文件操作

 1. 重新载入所有配置
```
/api/config?action=reload
```
 2. 保存当前配置
 （将当前内存中的配置保存到配置文件）
```
/api/config?action=save&mod=[参数1]&debug=[参数2]
mod=all_mod --- 表示保存所有配置模块,以及针对host的过滤规则
mod=[base/realIpFrom_Mod/host_method_Mod/rewrite_Mod/host_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg]

debug=no --- 表示关闭调试，即会覆盖模块对应的配置文件，默认是在对应目录中新建一个对应bak文件
```

# /api/config_dict
配置操作

 - 增 action=add
 ```
 /api/config_dict?action=add&mod=[参数1]&id=[参数2]&value=[参数3]&value_type=[参数4]
 mod=[realIpFrom_Mod/host_method_Mod/rewrite_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg]
 id=[仅当mod=realIpFrom_Mod/denyMsg时使用]，realIpFrom_Mod的序列不是数字，而是host。
 value=[增加的内容]
 value_type=[json] 表示传递的value是一个json,其余当做字符串
 
 EG:
 /api/config_dict?action=add&mod=args_Mod&value_type=json&value={"state":"on","action":"deny","hostname":["*",""],"args":["select.+(from)","jio"]}
 
 /api/config_dict?action=add&mod=realIpFrom_Mod&id=101.200.122.200&value_type=json&value={"ips":["*",""],"realipset":"x-for-f"}
 
  返回：
 {"code":true,"value":[value],"mod":[mod]}   ---- 正常
 {"code":"error",msg:"错误原因"} ---- 错误等
 ```
 - 删 action=del
 ```
  /api/config_dict?action=del&mod=[参数1]&id=[参数2]
  mod=[realIpFrom_Mod/host_method_Mod/rewrite_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg]
  id=[需要删除的id]
  
  EG:
  /api/config_dict?action=del&mod=realIpFrom_Mod&id=101.200.122.200
  
  /api/config_dict?action=del&mod=args_Mod&id=2
  
  返回：
  {"code":true,"mod":mod,"id":id}  ---- 正常
  {"code":"error",msg:"错误原因"} ---- 错误等
  
 ```
 - 改 action=set
 ```
 /api/config_dict?action=set&mod=[参数1]&id=[参数2]&value=[参数3]&value_type=[参数4]
  mod=[base/realIpFrom_Mod/host_method_Mod/rewrite_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg]
  id=[需要修改的id] ，id没有表示修改整个mod
  value=[修改后的内容]，如果是json，需要标记value_type
  value_type=[json]，默认是为字符串
  
  EG:
  /api/config_dict?action=set&mod=post_Mod&id=1&value_type=json&value={"state":"on","action":"log","post":["\\.\\.\/","jio"],"hostname":["*",""]}
  
 /api/config_dict?action=set&mod=base&id=replace_Mod&value=on
 
 /api/config_dict?action=set&mod=realIpFrom_Mod&id=101.200.122.200:5460&value_type=json&value={"ips":["*",""],"realipset":"v-realip-from"}
  
  返回：
  {"new_value":value,"code":true,"old_value":"原id的值"} ---- 正常
  {"code":"error","msg":"错误原因"} ---- 错误等
 ```
 - 查 action=get
 ```
 /api/config_dict?action=get&mod=[参数1]&id=[参数2]
 
 mod=all_mod -- 表示显示所有模块
 mod=count_mod -- 显示模块个数
 mod=空  -- 显示所有模块名称
 mod=[base/realIpFrom_Mod/host_method_Mod/rewrite_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg]
  id=空 -- 显示模块所有内容和状态
  id=count_id -- 显示对应模块的id个数
  id=[其他] -- 显示对应模块指定id的内容
  
  EG:
  GET /api/config_dict?action=get&mod=args_Mod
  
  GET /api/config_dict?action=get&mod=all_mod
  
  GET /api/config_dict?action=get&mod=args_Mod&id=1
  
  GET /api/config_dict?action=get&mod=args_Mod&id=count_id
  
 
 ```
 
# /api/ip_dict

 ip黑白名单操作
 
 - 增 action=add
 ```
 /api/ip_dict?action=add&id=[参数1]&value=[参数2]&time=[参数3]
 time = [默认为0]
 value = [默认为deny]
 
 EG：
 /api/ip_dict?action=add&id=101.200.122.200&value=deny&time=10
 
 /api/ip_dict?action=add&id=www.baidu.com-101.200.122.200&value=deny&time=10
 
 返回：
 {"add":true,"value":value,"id":id} -- 正常
 {code="error",msg="错误原因"}      -- 错误等
 ```
 - 删 action=del
 ```
 /api/ip_dict?action=del&id=[参数1]
 
 EG:
 /api/ip_dict?action=del&id=114.111.166.9
 
 返回：
 {"code":true,"flush_expired":0} -- 正常
 {code="error",msg="错误原因"}      -- 错误等
 
 ```
 - 改 action=set
 ```
 /api/ip_dict?action=set&id=[参数1]&value=[参数2]&time=[参数3]
 time = [默认为0]
 value = [默认为deny]
 
 EG:
 /api/ip_dict?action=set&id=127.0.0.1
 /api/ip_dict?action=set&id=127.0.0.1&value=allow&time=0
 
 返回：
 {"id":id,"code":true,"value":value}  -- 正常
 
 {"id":id,"code":false,"value":value} -- 错误等
 {code="error",msg="错误原因"}
 ```
 - 查 action=get
 ```
 /api/ip_dict?action=get&id=[参数1]
 id=all_id -- 表示显示所有内容
 id=count_id -- 显示id个数
 id=空  -- 显示所有id名称
 id=[其他] -- 显示对应id的值
 
 ```
 
# /api/read_dict

 字典查询接口
 
 - 查 action=get
 
 ```
  /api/read_dict?action=get&dict=[参数1]&id=[参数2]
  dict=[config_dict/count_dict/limit_ip_dict/token_dict/ip_dict]
  id=all_id -- 显示对应字典所有的key和value
  id=count_id -- 显示个数
  id=空  -- 显示对应字典所有key名称
  id=[其他key] -- 显示指定key的内容
  EG:
  /api/read_dict?action=get&dict=count_dict&id=all_id

 ```

# /api/redis

  redis相关操作
  
  - set key action=set
  ```
  /api/redis?action=set&key=[参数1]&value=[参数2]

  EG:
  /api/redis?action=set&key=aaa&value=ijdkdn

  注：如果是推送配置请使用push
  可作为redis调试使用
  ```

  - get key action=get
  ```
  /api/redis?action=get&key=[参数1]

  注：可查询远程模块配置情况
  key=[*/redis db 0 中任何key]

  EG:
  /api/redis?action=get&key=base

  ```

  - push 推送本地配置到redis action=push
```
/api/redis?action=push&key=[参数1]
key=config_dict  -- 表示将本地 config_dict字典 配置推送到redis
返回：
["name1":ok,"name2":ok,...]   -- 表示对应name 操作正常

key=count_dict   -- 表示将本地的 count_dict字典 计数信息推送到redis
返回：
set count_dict result: OK   -- 正常

key=ip_dict      -- 表示将本地的 ip_dict字典 永久的IP黑白名单推送到redis db 1中
返回：
["name1":ok,"name2":ok,...]   -- 表示对应name 操作正常

key=host_dict     -- 表示将本地的 host_dict字典 推送到redis 对应host执行的规则过滤,一个key为host_Mod,其余以%host%_HostMod命名

返回：
["name1":ok,"name2":ok,...]   -- 表示对应name 操作正常

key=[base/realIpFrom_Mod/host_method_Mod/rewrite_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg] -- 表示推送本地 config_dict字典 指定key到redis
返回：
set $key result: OK    -- 正常

EG:
/api/redis?action=push&key=config_dict
/api/redis?action=push&key=count_dict
/api/redis?action=push&key=host_dict
/api/redis?action=push&key=ip_dict -- 该数据存到 db 1 中，其他都在 默认 0 中
/api/redis?action=push&key=base

```
  - pull 拉取redis配置到本地 action=pull

```
/api/redis?action=pull&key=[参数1]
key = config_dict  -- 表示拉取所有配置到本地
返回：
It is Ok !   --  正常

key = host_dict    -- 表示拉取host_Mod数据到host_dict中
返回：
It is Ok !   --  正常

key = ip_dict    -- 表示拉取ip名单列表ip_dict中 包含ttl信息
返回：
It is Ok !   --  正常

key = [base/realIpFrom_Mod/host_method_Mod/rewrite_Mod/app_Mod/referer_Mod/url_Mod/header_Mod/useragent_Mod/cookie_Mod/args_Mod/post_Mod/network_Mod/replace_Mod/denyMsg] -- 表示拉取指定模块到本地
返回：
{"code"=true,"key"=_key,"redis_value"=res,"dict_value"=_dict_value} -- 正常

EG:
/api/redis?action=pull&key=config_dict
/api/redis?action=pull&key=host_dict
/api/redis?action=pull&key=ip_Mod
/api/redis?action=pull&key=app_Mod/base

```
 
# /api/token_dict
 token相关操作
 
 - get action=get
   ```
   /api/token_dict?action=get&token=[参数1]
   token=count_token -- 获取token数量
   token=all_token   -- 获取所有内容
   token=空       -- 获取所有token名称
   token=[其他]   -- 获取指定token的值
   
   EG:
   /api/token_dict?action=get&token=all_token
   /api/token_dict?action=get&token=count_token
   /api/token_dict?action=get&token=aaa
   
   ```
 - set action=set
   ```
   /api/token_dict?action=set&token=[参数1]
   token=[默认系统生成随机字符串]
   
   EG：
   /api/token_dict?action=set&token=asdfasdfweewew
   
   ```
   
# /api/nginx
 对nginx进程的简单操作
 
 - 重启 action=reload
 ```
 /api/nginx?action=reload
 
 返回：
 0  -- 表示成功  其余都失败
 ```
 - 检查 默认动作 [nginx -t]
 ```
 /api/nginx
 返回：
 0  -- 表示成功  其余都失败
 ```

# /api/host_dict
   对应host执行的规则操作

   - 增 action=add

   ```
    api/host_dict?action=add&host=[参数1]&id=[参数2]&value_type=[参数3]&value=[参数4]
    1：添加一个host状态，后续才能添加其规则
    api/host_dict?action=add&host=www.abc.com&id=state&value=on
    value=默认 off

    2：添加一条规则
    api/host_dict?action=add&host=www.abc.com&value_type=json&value=[规则]
    value_type=默认 json

    EG: 
    正则 匹配url 动作：允许 
    value={"state":"on","action":["allow","url"],"url":["\\.(css|js|flv|swf|woff|txt)$","jio"]}
    
    包含 匹配referer 动作：记录
    {"state":"on","action":["log","referer"],"url":["\\.(gif|jpg|png|jpeg|bmp|ico)$","jio"],"referer":["hao123","in"]}

    包含 匹配useragent 动作：拒绝
    {"state":"on","action":["deny","useragent"],"useragent":["baidu","in"]}

    等于 匹配url and network阈值 动作：拒绝 （暂不能为其他动作）
    {"state":"on","action":["deny","network"],"url":["\/index.html",""],"network":{"blackTime":600,"maxReqs":30,"pTime":10}}

    返回：
    {"code":true,"value"=value}   -- 表示正常

   ```

   - 删 action=del

  ```
   api/host_dict?action=add&host=[参数1]&id=[参数2]
   id就表示需要删除的哪一条规则记录，关于id，可以从get操作获取

   返回：
   {"code"=true,id=id,value=value}  -- 表示正常

  ```

   - 改 action=set

   ```
   api/host_dict?action=set&host=[参数1]&id=[参数2]&value_type=[参数3]&value=[参数4]
   id=state   -- 表示修改 对应host的规则总开关
   value= 默认 off

   返回：
   {"code"=true,"host"=host,"state"=state}  -- 表示正常
  
  
   id=[number] 表示修改 对应规则序号
   value_type=json  -- 表示 传递的value是一个json,默认是当做字符串
   value=[规则]

   返回：old_value 是原数据，new_value 是修改后的数据
   {"code"=true,"old_value"=old_host_id_mod,"new_value"=value}  -- 表示正常


   ```

   - 查 action=get

   ```
   api/host_dict?action=get&host=[参数1]&id=[参数2]

   host=all  -- 返回所有的host的规则

   host=all_host  -- 返回所有启用host规则的host名称

   host=[$host] -- 取对应host的规则,配置id参数
   id="" -- 返回对应host规则，包括状态，有序规则列表
   id=count_id -- 返回对应host规则，规则个数
   id=[number] -- 返回对应host规则中，指定id

   ```
