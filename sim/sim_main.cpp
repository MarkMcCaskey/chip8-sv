// SDL2 live-display harness for the verilated chip8_cpu (M9). This is the one
// place a C++ harness is worth it: a real window, real keyboard, real beeps,
// driving the exact same RTL the testbenches verify.
//
//   make run ROM=roms/1-chip8-logo.ch8
//
// Usage: chip8_sdl <rom.ch8> [--frames N]
//   --frames N   run N 60 Hz frames then exit (headless smoke test; pair with
//                SDL_VIDEODRIVER=dummy). 0 = run until the window closes.
//
// Timing model: the RTL is verilated with -GCYCLES_PER_TICK=64, and we clock
// it 64 cycles per rendered frame, so one 60 Hz timer tick == one frame and
// the CPU runs ~16 instructions/frame -- about the speed of a real COSMAC VIP.
//
// Keypad (classic mapping):   1 2 3 4        1 2 3 C
//                             Q W E R   ->   4 5 6 D
//                             A S D F        7 8 9 E
//                             Z X C V        A 0 B F

#include <SDL.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include "Vchip8_cpu.h"
#include "Vchip8_cpu___024root.h"

namespace {

constexpr int kScale = 10;               // 64x32 -> 640x320 window
constexpr int kCyclesPerFrame = 64;      // must match -GCYCLES_PER_TICK
constexpr int kAudioHz = 48000;
constexpr int kSamplesPerFrame = kAudioHz / 60;

struct KeyBinding {
    SDL_Scancode scancode;
    int key;
};
constexpr KeyBinding kKeymap[16] = {
    {SDL_SCANCODE_X, 0x0}, {SDL_SCANCODE_1, 0x1}, {SDL_SCANCODE_2, 0x2},
    {SDL_SCANCODE_3, 0x3}, {SDL_SCANCODE_Q, 0x4}, {SDL_SCANCODE_W, 0x5},
    {SDL_SCANCODE_E, 0x6}, {SDL_SCANCODE_A, 0x7}, {SDL_SCANCODE_S, 0x8},
    {SDL_SCANCODE_D, 0x9}, {SDL_SCANCODE_Z, 0xA}, {SDL_SCANCODE_C, 0xB},
    {SDL_SCANCODE_4, 0xC}, {SDL_SCANCODE_R, 0xD}, {SDL_SCANCODE_F, 0xE},
    {SDL_SCANCODE_V, 0xF},
};

void tick(Vchip8_cpu* top) {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        std::fprintf(stderr, "usage: %s <rom.ch8> [--frames N]\n", argv[0]);
        return 1;
    }
    long max_frames = 0;
    if (argc >= 4 && std::strcmp(argv[2], "--frames") == 0)
        max_frames = std::strtol(argv[3], nullptr, 10);

    // Read the ROM (at most the 3584 bytes that fit above 0x200).
    FILE* f = std::fopen(argv[1], "rb");
    if (!f) {
        std::fprintf(stderr, "cannot open ROM: %s\n", argv[1]);
        return 1;
    }
    std::vector<uint8_t> rom(4096 - 0x200);
    size_t rom_size = std::fread(rom.data(), 1, rom.size(), f);
    std::fclose(f);

    // Bring up the DUT: reset first, then poke the ROM into RAM (reset does
    // not touch memory contents).
    auto* top = new Vchip8_cpu;
    top->buttons = 0;
    top->rst = 1;
    for (int i = 0; i < 4; i++) tick(top);
    top->rst = 0;
    for (size_t i = 0; i < rom_size; i++)
        top->rootp->chip8_cpu__DOT__u_ram__DOT__memory[0x200 + i] = rom[i];

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) != 0) {
        std::fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }
    SDL_Window* win = SDL_CreateWindow("chip8-sv", SDL_WINDOWPOS_CENTERED,
                                       SDL_WINDOWPOS_CENTERED, 64 * kScale,
                                       32 * kScale, 0);
    SDL_Renderer* ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_PRESENTVSYNC);
    if (ren == nullptr)  // dummy video driver has no vsync
        ren = SDL_CreateRenderer(win, -1, 0);

    SDL_AudioSpec want{};
    want.freq = kAudioHz;
    want.format = AUDIO_S16SYS;
    want.channels = 1;
    want.samples = 1024;
    SDL_AudioDeviceID audio = SDL_OpenAudioDevice(nullptr, 0, &want, nullptr, 0);
    if (audio != 0) SDL_PauseAudioDevice(audio, 0);

    bool quit = false;
    long frame = 0;
    int phase = 0;
    uint32_t next_ms = SDL_GetTicks();
    while (!quit && (max_frames == 0 || frame < max_frames)) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT ||
                (ev.type == SDL_KEYDOWN && ev.key.keysym.sym == SDLK_ESCAPE))
                quit = true;
        }
        const Uint8* keys = SDL_GetKeyboardState(nullptr);
        uint16_t buttons = 0;
        for (const auto& b : kKeymap)
            if (keys[b.scancode]) buttons |= uint16_t(1) << b.key;
        top->buttons = buttons;

        for (int i = 0; i < kCyclesPerFrame; i++) tick(top);

        // 400 Hz square wave while the sound timer runs; cap the queue so a
        // long beep can't build up seconds of latency.
        if (audio != 0 && top->sound_on &&
            SDL_GetQueuedAudioSize(audio) < 4 * kSamplesPerFrame * sizeof(int16_t)) {
            int16_t buf[kSamplesPerFrame];
            for (int i = 0; i < kSamplesPerFrame; i++)
                buf[i] = ((phase++ / 60) % 2) ? 3000 : -3000;
            SDL_QueueAudio(audio, buf, sizeof(buf));
        }

        SDL_SetRenderDrawColor(ren, 20, 30, 20, 255);
        SDL_RenderClear(ren);
        SDL_SetRenderDrawColor(ren, 120, 255, 120, 255);
        for (int y = 0; y < 32; y++) {
            uint64_t row = top->rootp->chip8_cpu__DOT__fb[y];
            for (int x = 0; x < 64; x++) {
                if ((row >> (63 - x)) & 1) {
                    SDL_Rect r{x * kScale, y * kScale, kScale, kScale};
                    SDL_RenderFillRect(ren, &r);
                }
            }
        }
        SDL_RenderPresent(ren);
        frame++;

        next_ms += 16;  // ~60 fps pacing (vsync usually handles it anyway)
        uint32_t now = SDL_GetTicks();
        if (next_ms > now)
            SDL_Delay(next_ms - now);
        else
            next_ms = now;
    }

    // Headless smoke test support: report how much of the screen is lit so a
    // script (or a human) can tell the ROM actually drew something.
    int lit = 0;
    for (int y = 0; y < 32; y++)
        lit += __builtin_popcountll(top->rootp->chip8_cpu__DOT__fb[y]);
    std::printf("chip8_sdl: exited after %ld frames, %d pixels lit\n", frame, lit);

    if (audio != 0) SDL_CloseAudioDevice(audio);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    top->final();
    delete top;
    return 0;
}
