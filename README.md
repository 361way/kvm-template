kvm-template
============
[order by  www.361way.com](http://www.361way.com)<br />

这里一共有三个版本的脚本，作用是一致的都是利用模板来快速的创建kvm guest主机

    shell/create_kvm.sh为shell脚本版本 ，来自51cto上rolandqu写的一个版本
    v1.0为python重写的1.0版本 ，来自51cto坏男孩的版本
    v2.0为python重写的2.0版本 ，这个是我写的一个版本，主要参照坏男孩的版本，做了功能增强和xml块的优化
    
    
利用python脚本通过模板img和xml文件实现KVM的快速部署



v2.0用法为：
编辑conf里的配置文件，具体可以查看template2.py里的指向的配置文件 ，如果增加虚拟机使用add，删除使用delete参数


V2.0版里一定要指定6个参数，在删除guest主机时，后面两个参数可以随意写，不做验证


    #Action,Vm_name,Template_img_file,Template_xml_file,VM_mem,VM_vcpu
    add,mc,template.qcow2,template_qcow2.xml,1024,1
    delete,nagios,template.qcow2,template_qcow2.xml,0,0

编辑完conf里的ini文件后，执行python template2.py即可！

