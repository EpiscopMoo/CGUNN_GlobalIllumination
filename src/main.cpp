#include <windows.h>
#include <CommCtrl.h>
#include <stdio.h>
#include <malloc.h>
#include <memory.h>
#include <tchar.h>
#include "Resource.h"
#include "utils.h"
extern float3* cuda_main(int* w, int* h, float* cpu_presets, int preset_num, int samples = 128);
const char g_szClassName[] = "myWindowClass";

/*List of application logic globals*/
int samples_per_pixel = 128;
float diff_param1 = 1.0f;
float diff_param2 = 1.0f;

/*List of form control handle pointers */
HWND hWndComputeBtn = NULL;
HWND hWndSamplesTxt = NULL;
HWND hWndSamplesLbl = NULL;
HWND hWndPictureCtr = NULL;
HWND hWndPictureBox = NULL;
HWND hWndSliders[2];

/*Prorotypes*/
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
VOID WndControlsInit(HWND hwnd, WPARAM wParam, LPARAM lParam);
VOID WndControlsProc(HWND hwnd, WPARAM wParam, LPARAM lParam);


//The general purpose function for processing WM messages from the queue.
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch(msg)
    {
		case WM_CREATE:
			WndControlsInit(hwnd, wParam, lParam);
			break;
		case WM_COMMAND:
			WndControlsProc(hwnd, wParam, lParam);
			break;
        case WM_CLOSE:
            DestroyWindow(hwnd);
			return 0;

		case WM_HSCROLL:
			switch (LOWORD(wParam)) 
			{
			case TB_THUMBTRACK:
			case TB_THUMBPOSITION:
 
				if (hWndSliders[0] == (HWND)lParam) { // обработка события 1-го trackbar
					int val = HIWORD(wParam);
					diff_param1 = ((float)val)/20;
				}
				else if (hWndSliders[1] == (HWND)lParam) {  // обработка события 2-ого trackbar
					int val = HIWORD(wParam);
					diff_param2 = ((float)val)/20;
				}
 
				break;
			} 
		break;
        case WM_DESTROY:
            PostQuitMessage(0);
			return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
    LPSTR lpCmdLine, int nCmdShow)
{
    WNDCLASSEX wc;
    HWND hwnd;
    MSG Msg;

    wc.cbSize        = sizeof(WNDCLASSEX);
    wc.style         = 0;
    wc.lpfnWndProc   = WndProc;
    wc.cbClsExtra    = 0;
    wc.cbWndExtra    = 0;
    wc.hInstance     = hInstance;
    wc.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW);
    wc.lpszMenuName  = NULL;
    wc.lpszClassName = g_szClassName;
    wc.hIconSm       = LoadIcon(NULL, IDI_APPLICATION);

    if(!RegisterClassEx(&wc)) return -1;

    hwnd = CreateWindowEx(
        WS_EX_CLIENTEDGE,
        g_szClassName,
        "The Simplest CPU/CUDA Path Tracer",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, WIDTH, HEIGHT,
        NULL, NULL, hInstance, NULL);

    if(hwnd == NULL) return -2;

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    while(GetMessage(&Msg, NULL, 0, 0) > 0)
    {
        TranslateMessage(&Msg);
        DispatchMessage(&Msg);
    }
    return Msg.wParam;
}

//Creates form controls at specified positions, populates control handle pointers.
VOID WndControlsInit(HWND hwnd, WPARAM wParam, LPARAM lParam)
{	
	HGDIOBJ hfDefault = GetStockObject(DEFAULT_GUI_FONT);
	hWndComputeBtn = CreateWindowEx(NULL, 
		"BUTTON",
		"Start",
		WS_TABSTOP|WS_VISIBLE|WS_CHILD|BS_DEFPUSHBUTTON,
		25,
		80,
		100,
		24,
		hwnd,
		(HMENU)IDC_COMPUTE_BUTTON,
		GetModuleHandle(NULL),
		NULL);
	SendMessage(hWndComputeBtn, WM_SETFONT, (WPARAM)hfDefault, MAKELPARAM(FALSE,0));
	hWndSamplesTxt = CreateWindowEx(WS_EX_CLIENTEDGE,
		"EDIT",
		"32",
		WS_CHILD|WS_VISIBLE|ES_MULTILINE|ES_AUTOVSCROLL|ES_AUTOHSCROLL,
		25,
		50,
		50,
		24,
		hwnd,
		(HMENU)IDC_SAMPLES_TEXTBOX,
		GetModuleHandle(NULL),
		NULL);
	SendMessage(hWndSamplesTxt, WM_SETFONT, (WPARAM)hfDefault, MAKELPARAM(FALSE,0));
	hWndSamplesLbl = CreateWindow("static", "ST_U",
                              WS_CHILD | WS_VISIBLE | WS_TABSTOP,
                              25, 25, 140, 24,
							  hwnd, (HMENU)(IDC_SAMPLES_LABEL),
                              /*(HINSTANCE) GetWindowLong (hwnd, GWL_HINSTANCE)*/GetModuleHandle(NULL), NULL);
	SetWindowText(hWndSamplesLbl, "Samples per pixel:");
	SendMessage(hWndSamplesLbl, WM_SETFONT, (WPARAM)hfDefault, MAKELPARAM(FALSE,0));
	hWndPictureCtr = CreateWindow("static", "",
		WS_CHILD|WS_VISIBLE,
		200, 25, 512, 512,
		hwnd, (HMENU)(IDC_PICTURE_CONTAINER),
		(HINSTANCE) GetWindowLong (hwnd, GWL_HINSTANCE), NULL);
	hWndPictureBox = CreateWindow("static", "",
		WS_CHILD|WS_VISIBLE|SS_BITMAP,
		200, 25, 512, 512,
		hwnd, (HMENU)(IDC_PICTUREBOX),
		(HINSTANCE) GetWindowLong (hwnd, GWL_HINSTANCE), NULL);

	//label
	CHAR spos[64];
	for (int i = 0; i < sizeof(hWndSliders) / sizeof(hWndSliders[0]); i++) 
	{
        hWndSliders[i] = CreateWindow(TRACKBAR_CLASS, "", WS_CHILD | WS_VISIBLE | TBS_HORZ | TBS_AUTOTICKS,
            15, 135 + i * 70, 150, 50, hwnd, 0, (HINSTANCE)GetWindowLong(hwnd, GWL_HINSTANCE), NULL);
        ShowWindow(hWndSliders[i], SW_SHOW);
        UpdateWindow(hWndSliders[i]);
        SendMessage(hWndSliders[i], TBM_SETRANGE, (WPARAM)TRUE, (LPARAM)MAKELONG(0, 20)); //20 - количество позиций трекбара
    }
}

//Defines which control triggered the message.
VOID WndControlsProc(HWND hwnd, WPARAM wParam, LPARAM lParam)
{
	switch(LOWORD(wParam))
	{
	case IDC_COMPUTE_BUTTON:
		{
			//Take value from textbox and use it as 'spp' value. Begin computations.
			char buffer[5];
			SendMessage(hWndSamplesTxt,
				WM_GETTEXT,
				sizeof(buffer)/sizeof(buffer[0]),
				reinterpret_cast<LPARAM>(buffer));
			if (sscanf(buffer, "%d", &samples_per_pixel) != EOF)
			{
				int w,h;
				float presets[] = { 1.0f, 0.0f, diff_param1, diff_param2 };
				float3* pixels = cuda_main(&w, &h, presets, 4, samples_per_pixel);
				drawbmp("image", pixels, w, h);
				HANDLE hImage = LoadImage(NULL, "image", IMAGE_BITMAP, w, h, LR_LOADFROMFILE);
				SendMessage(hWndPictureBox, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)hImage);
			}
		}
		break;
	}
}