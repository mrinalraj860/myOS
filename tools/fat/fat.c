#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct
{
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector; // 512 bytes
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntriesCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // Extended BIOS Parameter Block
    // uint8_t PhysicalDriveNumber;
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;
    uint8_t VolumeLabel[11];
    uint8_t SystemId[8];

    // At this stage lets not care about the code ...

} __attribute__((packed)) BootSector; // This attribute tells the compiler to not add any padding to the structure

// Directory structure as per FAT structure
typedef struct
{
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreationTimeTenths;
    uint16_t CreationTime;
    uint16_t CreationDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;

} __attribute__((packed)) DirectoryEntry;

uint8_t *g_fat = NULL;
BootSector g_BootSector;
DirectoryEntry *g_rootDirectory = NULL;
uint32_t g_rootDirectoryEnd;

bool readBootSector(FILE *disk)
{
    // The function returns the number of elements that are read successfully from the file. If return value is less than the
    // number of elements requested, either an error occurred or the end of file was reached. If The function returns the number of elements that are
    // read successfully from the file
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk);
}

bool readSectors(FILE *disk, uint32_t lba, uint32_t count, void *bufferOut)
{
    bool ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);       // O is for flase and is it is false then it fails;  offset is lba * g_BootSector.BytesPerSector
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count); // Read Number of sectors from the location and check if that is equal to count
    return ok;
}

bool readRootDirectory(FILE *disk)
{
    uint32_t lba = g_BootSector.ReservedSectors + (g_BootSector.FatCount * g_BootSector.SectorsPerFat);
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntriesCount;
    uint32_t sectors = (size / g_BootSector.BytesPerSector) + ((size % g_BootSector.BytesPerSector) ? 1 : 0);
    g_rootDirectoryEnd = lba + sectors;
    g_rootDirectory = (DirectoryEntry *)malloc(sectors * g_BootSector.BytesPerSector);
    if (!g_rootDirectory)
    {
        return false;
    }
    return readSectors(disk, lba, sectors, g_rootDirectory);
}

bool readFat(FILE *disk)
{
    g_fat = (uint8_t *)malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    if (!g_fat)
    {
        return false;
    }

    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_fat);
}

DirectoryEntry *findFile(const char *name) // Its const because we dont want to change the name
{
    for (uint32_t i = 0; i < g_BootSector.DirEntriesCount; i++)
    {
        printf("Name: %s\n", g_rootDirectory[i].Name);
        if (memcmp(name, g_rootDirectory[i].Name, 11) == 0)
        {
            return &g_rootDirectory[i];
        }
    }

    return NULL;
}

bool readFile(DirectoryEntry *fileEntry, FILE *disk, uint8_t *outputBuffer)
{
    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do
    {
        uint32_t lba = g_rootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;

        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0)
        {
            currentCluster = (*(uint16_t *)(g_fat + fatIndex)) & 0x0FFF;
        }
        else
        {
            currentCluster = (*(uint16_t *)(g_fat + fatIndex)) >> 4;
        }
    } while (ok && currentCluster < 0x0FF8);

    return ok;
}

int main(int argc, char **argv)
{
    if (argc < 3)
    {
        printf("Syntax: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE *disk = fopen(argv[1], "rb");
    if (!disk)
    {
        fprintf(stderr, "Error: Unable to open disk image %s\n", argv[1]);
        return -1;
    }

    if (!readBootSector(disk))
    {
        fprintf(stderr, "Error: Unable to read boot sector\n");
        return -2;
    }

    if (!readFat(disk))
    {
        fprintf(stderr, "Error: Unable to read FAT\n");
        free(g_fat);
        return -3;
    }
    if (!readRootDirectory(disk))
    {
        fprintf(stderr, "Error: Unable to read root directory\n");
        free(g_fat);
        free(g_rootDirectory);
        return -4;
    }

    DirectoryEntry *fileEntry = findFile(argv[2]);
    if (!fileEntry)
    {
        fprintf(stderr, "Error: File not found: %s\n", argv[2]);
        free(g_fat);
        fclose(disk);
        return -5;
    }

    uint8_t *outputBuffer = (uint8_t *)malloc(fileEntry->Size + g_BootSector.BytesPerSector); // Allocate memory for the output buffer its better to allocate 1 sector ore than the file size
    if (!readFile(fileEntry, disk, outputBuffer))
    {
        fprintf(stderr, "Error: Unable to read file\n");
        free(g_fat);
        free(g_rootDirectory);
        free(outputBuffer);
        return -6;
    }

    for (size_t i = 0; i < fileEntry->Size; i++)
    {
        if (isprint(outputBuffer[i]))
            fputc(outputBuffer[i], stdout);
        else
            printf("<%02x>", outputBuffer[i]);
    }
    printf("\n");

    free(g_rootDirectory);
    free(g_fat);
    return 0;
}