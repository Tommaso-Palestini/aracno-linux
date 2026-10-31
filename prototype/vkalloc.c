/* Octopus prototipo — fase 4.3: alloca MB di memoria device-local (VRAM) con Vulkan
 * e la tiene allocata finché il processo vive.
 * Uso: vkalloc MB
 * Compilazione: gcc -O2 -o vkalloc vkalloc.c -lvulkan
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <vulkan/vulkan.h>

#define CHECK(x, msg)                                                   \
    do {                                                                \
        VkResult r_ = (x);                                              \
        if (r_ != VK_SUCCESS) {                                         \
            printf("ERRORE %s: VkResult %d\n", msg, (int)r_);           \
            return 1;                                                   \
        }                                                               \
    } while (0)

int main(int argc, char **argv) {
    uint64_t mb = argc > 1 ? strtoull(argv[1], NULL, 10) : 256;

    VkApplicationInfo app = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
                              .apiVersion = VK_API_VERSION_1_0 };
    VkInstanceCreateInfo ici = { .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                                 .pApplicationInfo = &app };
    VkInstance inst;
    CHECK(vkCreateInstance(&ici, NULL, &inst), "vkCreateInstance");

    uint32_t n = 0;
    CHECK(vkEnumeratePhysicalDevices(inst, &n, NULL), "conteggio dispositivi");
    if (n == 0) {
        printf("ERRORE nessun dispositivo Vulkan\n");
        return 1;
    }
    VkPhysicalDevice *pds = malloc(n * sizeof *pds);
    CHECK(vkEnumeratePhysicalDevices(inst, &n, pds), "enumerazione dispositivi");
    VkPhysicalDevice pd = pds[0];

    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(pd, &props);
    printf("dispositivo: %s\n", props.deviceName);

    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(pd, &mp);
    uint32_t type = UINT32_MAX;
    for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
        if (mp.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) {
            type = i;
            break;
        }
    }
    if (type == UINT32_MAX) {
        printf("ERRORE nessun tipo di memoria device-local\n");
        return 1;
    }

    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci = { .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                                    .queueFamilyIndex = 0,
                                    .queueCount = 1,
                                    .pQueuePriorities = &prio };
    VkDeviceCreateInfo dci = { .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                               .queueCreateInfoCount = 1,
                               .pQueueCreateInfos = &qci };
    VkDevice dev;
    CHECK(vkCreateDevice(pd, &dci, NULL, &dev), "vkCreateDevice");

    VkMemoryAllocateInfo mai = { .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                                 .allocationSize = mb * 1024ULL * 1024ULL,
                                 .memoryTypeIndex = type };
    VkDeviceMemory mem;
    CHECK(vkAllocateMemory(dev, &mai, NULL, &mem), "vkAllocateMemory");

    printf("ok: %llu MB allocati in memoria device-local (tipo %u)\n",
           (unsigned long long)mb, (unsigned)type);
    fflush(stdout);

    while (1)
        sleep(60);
}
