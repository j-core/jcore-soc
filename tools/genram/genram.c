/*=======================================================================*/
/* Generate RAM Initialize file for Xilinx Block RAM (16KB)              */
/*-----------------------------------------------------------------------*/
/* Rev.1 January 21,2003 by Thorn Aitch : prototype                      */
/* Rev.2 April   30,2003 by Thorn Aitch : 8KB -> 16KB                    */
/*                                                                       */
/*    Usage:                                                             */
/*    genram [filename]                                                  */
/*        [filename] : (Input ) Binary File Name of Motolora S-Format.   */
/*        ram.dat    : (Output) Constraints Data (Append it to *.ucf.)   */
/*=======================================================================*/

#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <stdlib.h>

#ifndef RAMSIZE
#define RAMSIZE 32768 /* unit : byte */
#endif
#define MAXLINE 1000
#define MAXWORD 100


/*=============*/
/* main routine*/
/*=============*/
int main(int argc, char *argv[])
{
	FILE	*memFp;
	FILE	*ramFp;
	char	memLine[MAXLINE];
	char	hex[MAXWORD];
	char	*pMemLine, *pHex, *SkipSpace();
	int	i, j, errStx, recType, numCode;
	unsigned long ram[RAMSIZE];
	unsigned long addr;
	unsigned long data;

	if (argc != 2)
	{

 		printf("\n");
		printf("====================================================\n");
		printf("==== Generate RAM Initialize Data from S-Format ====\n");
		printf("====================================================\n");
		printf("[Command Usage]\n");
		printf("    genram [filename]\n");
		printf("\n");
		printf("        [filename] : (input ) Binary File Name of Motorola S-Format.\n");
        printf("        ram.dat    : (Output) Constraints Data (Append it to *.ucf.)\n");
		printf("\n");
		return(1);
	}

	/*------------------*/
	/* initialize ram[] */
	/*------------------*/
	for (i = 0 ; i < RAMSIZE ; i++)
	{
		ram[i] = 255; /* init values are all FF */
	}

	/*-----------------------------*/
	/* read s-format file to rom[] */
	/*-----------------------------*/
	if ((memFp = fopen(argv[1], "r")) == NULL)
	{
 		printf("ERROR:cant open the file.\n");
		return(2);
	}
	errStx = 0;
	pHex = hex;
	while (fgets(memLine, MAXLINE, memFp) != NULL)
	{
		pMemLine = memLine;
		pMemLine = SkipSpace(pMemLine);

		if (*pMemLine++ != 'S') /* start mark ? */
		{
			errStx = 1;
			break;
		}

		if ((*pMemLine == '0') || (*pMemLine == '5')) continue;	/* if comment ? */

		if (*pMemLine == '1') recType = 1;						/* record type */
		else if (*pMemLine == '2') recType = 2;
		else if (*pMemLine == '3') recType = 3;
		else if (*pMemLine == '7') break;
		else if (*pMemLine == '8') break;
		else if (*pMemLine == '9') break;
		else
		{
		errStx = 1;
		break;
		}
		pMemLine++;

		pHex = strncpy(pHex,pMemLine,2);				/* the number of code */
		pMemLine = pMemLine + 2;
		*(pHex + 2) = '\0';
		if ((ChkHex(pHex) == 0) || (sscanf(pHex,"%X",&numCode) == EOF))
		{
			errStx = 1;
			break;
		}

		if (recType == 1)								/* load address */
		{
			pHex = strncpy(pHex,pMemLine,4);
			pMemLine = pMemLine + 4;
			numCode = numCode - 2;
			*(pHex + 4) = '\0';
			if (strlen(pHex) != 4)
			{
				errStx = 1;
				break;
			}
		}
		if (recType == 2)
		{
			pHex = strncpy(pHex,pMemLine,6);
			pMemLine = pMemLine + 6;
			numCode = numCode - 3;
			*(pHex + 6) = '\0';
			if (strlen(pHex) != 6)
			{
				errStx = 1;
				break;
			}
		}
		if (recType == 3)
		{
			pHex = strncpy(pHex,pMemLine,8);
			pMemLine = pMemLine + 8;
			numCode = numCode - 4;
			*(pHex + 8) = '\0';
			if (strlen(pHex) != 8)
			{
				errStx = 1;
				break;
			}
		}

		if ((ChkHex(pHex) == 0) || (sscanf(pHex,"%lX",&addr) == EOF))
		{
			errStx = 1;
			break;
		}

		for (i = 0 ; i < numCode - 1 ; i++)				/* code */
		{
			pHex = strncpy(pHex,pMemLine,2);
			pMemLine = pMemLine + 2;
			*(pHex + 2) = '\0';
			if (strlen(pHex) != 2)
			{
				errStx = 1;
				break;
			}
			if ((ChkHex(pHex) == 0) || (sscanf(pHex,"%lX",&data) == EOF))
			{
				errStx = 1;
				break;
			}
			if (addr <= RAMSIZE)
			{
				ram[addr] = data;
				addr++;
			}
			else
			{
				errStx = 2;
				break;
			}
		}
		if (errStx != 0) break;
	}

	if (errStx == 1)
	{ 
		printf("ERROR:syntax error in object file.\n");
		return(2);
	}
	if (errStx == 2)
	{
		printf("ERROR:rom address out of range.\n");
		return(2);
	}
	if (fclose(memFp) == EOF)
	{
 		printf("ERROR:file close error.\n");
		return(2);
	}

	/*-------------------*/
	/* open ram.dat file */
	/*-------------------*/
	if ((ramFp = fopen("ram.dat", "w")) == NULL)
	{
 		printf("ERROR:cant open ram.dat.\n");
		return(3);
	}

    /*-------------------------------*/
    /* RAM0HH : HH lane of 0000-1FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM0HH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[j+0]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM0HL : HL lane of 0000-1FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM0HL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[j+1]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM0LH : LH lane of 0000-1FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM0LH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[j+2]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM0LL : LL lane of 0000-1FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM0LL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[j+3]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM1HH : HH lane of 2000-3FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM1HH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x2000+j+0]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM1HL : HL lane of 2000-3FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM1HL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x2000+j+1]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM1LH : LH lane of 2000-3FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM1LH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x2000+j+2]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM1LL : LL lane of 2000-3FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM1LL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x2000+j+3]);
        }
        fprintf(ramFp, ";\n");
    }


    /*-------------------------------*/
    /* RAM2HH : HH lane of 4000-5FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM2HH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x4000+j+0]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM2HL : HL lane of 4000-5FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM2HL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x4000+j+1]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM2LH : LH lane of 4000-5FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM2LH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x4000+j+2]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM2LL : LL lane of 4000-5FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM2LL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x4000+j+3]);
        }
        fprintf(ramFp, ";\n");
    }


    /*-------------------------------*/
    /* RAM3HH : HH lane of 6000-7FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM3HH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x6000+j+0]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM3HL : HL lane of 6000-7FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM3HL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x6000+j+1]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM3LH : LH lane of 6000-7FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM3LH\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x6000+j+2]);
        }
        fprintf(ramFp, ";\n");
    }

    /*-------------------------------*/
    /* RAM3LL : LL lane of 6000-7FFF */
    /*-------------------------------*/   
    for (i = 0x00 ; i < 0x40 ; i++)
    {
        fprintf(ramFp, "INST \"MEMORY/Mram_RAM3LL\" INIT_%02X = ", i);
        for (j = (i+1)*0x80-4 ; j >= i*0x80 ; j = j - 4)
        {
            fprintf(ramFp, "%02lX", ram[0x6000+j+3]);
        }
        fprintf(ramFp, ";\n");
    }

	/*--------------------*/
	/* write ram.dat file */
	/*--------------------*
	if (fclose(ramFp) == EOF)
	{
 		printf("ERROR:file close error.\n");
		return(3);
	}

	/*-----------------------------------------*/
	return(0);
}

/*============*/
/* skip space */
/*============*/
char *SkipSpace(pStr)
	char	*pStr;
{
	while(isspace((int) *pStr)) pStr++;
	return(pStr);
}

/*===========*/
/* check hex */
/*===========*/
int ChkHex(str)
	char	*str;
{
	int		result;
	
	result = 0;
	while(*str != '\0')
	{
		result = isxdigit(*(str++));
		if (result == 0) break;
	}
	return(result);
}

/* end of source file */


