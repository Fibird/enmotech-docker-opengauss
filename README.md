# 说明

本镜像仓库来基于[墨天轮](https://github.com/enmotech)的[opengauss镜像](https://github.com/enmotech/enmotech-docker-opengauss)，感谢他们对于开源社区的贡献。


# 支持的tags

- latest: 基于共享存储的Serverless OpenGauss主从集群；
- 1.0.1: 基于共享存储的Serverless OpenGauss主从集群；
- debug: 可用于debug调试的docker容器；
- origin: 原始OpenGauss容器，从节点会重复写数据。

# 关于Serverless-openGauss

Serverless OpenGauss是一款基于共享存储的分布式数据，为了保障数据的高可用性，建议使用分布式存储，如Ceph、lustre等，目前仍在开发中...

# 如何使用本镜像

## 启动openGuass实例

```console
$ docker run --name opengauss --privileged=true -d -e GS_PASSWORD=Enmo@123 fibird/opengauss:latest
```

## 环境变量

为了更灵活的使用openGuass镜像，可以设置额外的参数。未来我们会扩充更多的可控制参数，当前版本支持以下变量的设定。

### `GS_PASSWORD`

在你使用openGauss镜像的时候，必须设置该参数。该参数值不能为空或者不定义。该参数设置了openGauss数据库的超级用户omm以及测试用户gaussdb的密码。openGauss安装时默认会创建omm超级用户，该用户名暂时无法修改。测试用户gaussdb是在[entrypoint.sh](https://github.com/fibird/enmotech-docker-opengauss/blob/master/1.0.1/entrypoint.sh)中自定义创建的用户。

openGauss镜像配置了本地信任机制，因此在容器内连接数据库无需密码，但是如果要从容器外部（其它主机或者其它容器）连接则必须要输入密码。

**openGauss的密码有复杂度要求，需要：密码长度8个字符及以上，必须同时包含英文字母大小写，数字，以及特殊符号**

### `GS_NODENAME`

指定数据库节点名称 默认为gaussdb

### `GS_USERNAME`

指定数据库连接用户名 默认为gaussdb

### `GS_PORT`

指定数据库端口，默认为5432。

## 从容器外部连接容器数据库

openGauss的默认监听启动在容器内的5432端口上，如果想要从容器外部访问数据库，则需要在`docker run`的时候指定`-p`参数。比如以下命令将允许使用8888端口访问容器数据库。

```console
$ docker run --name opengauss --privileged=true -d -e GS_PASSWORD=Enmo@123 -p 8888:5432 fibird/opengauss:latest
```

在上述命令正常启动容器数据库之后，可以通过外部的gsql进行数据库访问。

```console
$ gsql -d postgres -U gaussdb -W'Enmo@123' -h your-host-ip -p8888
```

## 持久化存储数据

容器一旦被删除，容器内的所有数据和配置也均会丢失，而从镜像重新运行一个容器的话，则所有数据又都是呈现在初始化状态，因此对于数据库容器来说，为了防止因为容器的消亡或者损坏导致的数据丢失，需要进行持久化存储数据的操作。通过在`docker run`的时候指定`-v`参数来实现。比如以下命令将会指定将openGauss的所有数据文件存储在宿主机的/enmotech/opengauss下。

```console
$  docker run --name opengauss --privileged=true -d -e GS_PASSWORD=secretpassword@123 \
    -v /enmotech/opengauss:/var/lib/opengauss \
    enmotech/opengauss:latest
```

## 创建基于共享存储的OpenGauss主从集群

创建容器镜像后执行脚本 [create_master_slave.sh](https://github.com/enmotech/enmotech-docker-opengauss/blob/master/create_master_slave.sh)自动创建openGauss主从架构。该脚本有多个自定义参数并设定默认值。

```
OG_SUBNET (容器所在网段) [172.11.0.0/24]  
GS_PASSWORD (定义数据库密码)[Enmo@123] 
SHARED_DATA_DIR（共享数据目录）[/mnt/cephfs/]
MASTER_IP (主库IP)[172.11.0.101]  
SLAVE_1_IP (备库IP)[172.11.0.102]  
MASTER_HOST_PORT (主库数据库服务端口)[5432]  
MASTER_LOCAL_PORT (主库通信端口)[5434]  
MASTER_CONFIG_PATH（主库配置文件路径）[/mnt/cephfs/og1]
SLAVE_1_HOST_PORT (备库数据库服务端口)[6432]  
SLAVE_1_LOCAL_PORT (备库通信端口)[6434] 
SLAVE_1_CONFIG_PATH（主库配置文件路径）[/mnt/cephfs/og2]
MASTER_NODENAME (主节点名称)[opengauss_master]  
SLAVE_NODENAME （备节点名称）[opengauss_slave1]  
```

## 如何编译镜像

首先将编译好的opengauss拷贝到1.0.1的目录下，然后运行以下脚本：

```
./buildDockerImage.sh -v <版本号> -i 
```

目前Serverless opengauss依赖于opengauss 1.0.1，因此版本号必须为1.0.1。

编译好之后，我们就可以将其上传到镜像仓库：

```
docker tag opengauss:1.0.1 fibird/opengauss:<镜像版本号>
docker push fibird/opengauss:<镜像版本号>
```

# License

Copyright (c) 2011-2020 Fibird
Copyright (c) 2011-2020 Enmotech

许可证协议遵循GPL v3.0，你可以从下方获取协议的详细内容。

    https://github.com/enmotech/enmotech-docker-opengauss/blob/master/LICENSE
