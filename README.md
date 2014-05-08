kvm-template
============

利用python脚本通过模板img和xml文件实现KVM的快速部署


用法为：
编辑conf里的配置文件，具体可以查看template1/2.py里的指向的配置文件 ，如果增加虚拟机使用add，删除使用delete参数


V2.0版里一定要指定6个参数，在删除里，后面两个参数可以随意写，不做验证


    #Action,Vm_name,Template_img_file,Template_xml_file,VM_mem,VM_vcpu
    add,mc,template.qcow2,template_qcow2.xml,1024,1
    delete,nagios,template.qcow2,template_qcow2.xml,0,0

完成后，修改完conf里的ini文件后，执行python template2.py即可！
