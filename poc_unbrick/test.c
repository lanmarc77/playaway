#include <stdint.h>
#define HW_PINCTRL_MUXSEL4_SET *(uint32_t*)0x80018144
#define HW_PINCTRL_MUXSEL4 *(uint32_t*)0x80018140
#define HW_PINCTRL_DRIVE8_SET *(uint32_t*)0x80018284
#define HW_PINCTRL_DOUT0_SET *(uint32_t*)0x80018404
#define HW_PINCTRL_DOUT0_CLR *(uint32_t*)0x80018408
#define HW_PINCTRL_DOUT2_SET *(uint32_t*)0x80018424
#define HW_PINCTRL_DOUT2_CLR *(uint32_t*)0x80018428
#define HW_PINCTRL_DOE0_SET *(uint32_t*)0x80018604
#define HW_PINCTRL_DOE0_CLR *(uint32_t*)0x80018604
#define HW_PINCTRL_DOE2_SET *(uint32_t*)0x80018624
#define HW_PINCTRL_MUXSEL1_SET *(uint32_t*)0x80018114
#define HW_PINCTRL_DRIVE2_SET *(uint32_t*)0x80018224
#define HW_PINCTRL_DRIVE2 *(uint32_t*)0x80018220
#define HW_USBPHY_PWD *(uint32_t*)0x8007C000
int c_entry() {
    HW_PINCTRL_MUXSEL1_SET=(3<<10);//GPMI_RDY3 configured as GPIO
    HW_PINCTRL_DRIVE2=HW_PINCTRL_DRIVE2&(~(uint32_t)(7<<20));
    HW_PINCTRL_DOUT0_SET=1<<21;//set ouput to specific value, GPMI_RDY3=BANK0_PIN21
    HW_PINCTRL_DOE0_SET=1<<21;//enable the output driver, GPMI_RDY3=BANK0_PIN21
    HW_USBPHY_PWD=0xFFFFFFFF;//power down USB
    uint32_t i=0;
    while(i<10000000){
        i++;
        if(i%60000<30000){
            HW_PINCTRL_DOUT0_SET=1<<21;//set ouput to specific value, GPMI_RDY3=BANK0_PIN21
        }else{
            HW_PINCTRL_DOUT0_CLR=1<<21;//set ouput to specific value, GPMI_RDY3=BANK0_PIN21
        }
    }
    *(uint32_t*)0x800400F0=0x02;//reset complete chip
    while(1);
}
