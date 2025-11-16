# OpenWrt计划弃用opkg，全面采用apk。这是一个默认使用opkg的固件。集成istore商店。带Docker。
# RE-SS-01-亚瑟-wifi、RE-CS-02-雅典娜-wifi。请注意选择你需要的设备固件！
# 固件已切换到6.12内核。
# OpenWRT-CI
云编译OpenWRT固件

官方版：
https://github.com/immortalwrt/immortalwrt.git

高通版：
https://github.com/VIKINGYFY/immortalwrt.git

# 固件简要说明：

固件不定时编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

MEDIATEK系列（不编译）、QUALCOMMAX系列（仅编译RE-SS-01-亚瑟-wifi、RE-CS-02-雅典娜-wifi）、ROCKCHIP系列（不编译）、X86系列。
# U-BOOT
高通版：
https://github.com/chenxin527/uboot-ipq60xx-emmc-build
联发科版：
https://drive.wrt.moe/uboot/mediatek

# 目录简要说明：

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置
