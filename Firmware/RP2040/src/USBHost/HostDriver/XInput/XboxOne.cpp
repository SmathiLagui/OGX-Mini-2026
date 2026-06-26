#include <cstring>

#include "host/usbh.h"
#include "Board/board_api.h"
#include "TaskQueue/TaskQueue.h"

#include "USBHost/HostDriver/XInput/tuh_xinput/tuh_xinput.h"
#include "USBHost/HostDriver/XInput/XboxOne.h"
#include "USBHost/HostDriver/XInput/XboxArcadeStick.h"

static constexpr uint32_t GUIDE_STALE_MS = 400u;

void XboxOneHost::initialize(Gamepad& gamepad, uint8_t address, uint8_t instance, const uint8_t* report_desc, uint16_t desc_len)
{
    uint16_t vid = 0;
    uint16_t pid = 0;
    tuh_vid_pid_get(address, &vid, &pid);
    gip_arcade_stick_ = XboxArcadeStick::is_xbox_one_gip(vid, pid);
    prev_arcade_len_ = 0;
    std::memset(&prev_in_report_, 0, sizeof(prev_in_report_));
    (void)gamepad;
    (void)report_desc;
    (void)desc_len;
    const uint8_t addr = address;
    const uint8_t inst = instance;
    TaskQueue::Core1::queue_delayed_task(
        TaskQueue::Core1::get_new_task_id(), 50, false,
        [addr, inst]() { tuh_xinput::start_xboxone(addr, inst); });
}

static void map_gip_buttons(Gamepad& gamepad, const XboxOne::InReport* in_report, Gamepad::PadIn& gp_in,
    uint8_t guide_pressed)
{
    const uint16_t b = in_report->buttons;
    if (b & XboxOne::GipWireButtons::DPAD_UP)    gp_in.dpad |= gamepad.MAP_DPAD_UP;
    if (b & XboxOne::GipWireButtons::DPAD_DOWN)  gp_in.dpad |= gamepad.MAP_DPAD_DOWN;
    if (b & XboxOne::GipWireButtons::DPAD_LEFT)  gp_in.dpad |= gamepad.MAP_DPAD_LEFT;
    if (b & XboxOne::GipWireButtons::DPAD_RIGHT) gp_in.dpad |= gamepad.MAP_DPAD_RIGHT;

    if (b & XboxOne::GipWireButtons::LEFT_THUMB)  gp_in.buttons |= gamepad.MAP_BUTTON_L3;
    if (b & XboxOne::GipWireButtons::RIGHT_THUMB) gp_in.buttons |= gamepad.MAP_BUTTON_R3;
    if (b & XboxOne::GipWireButtons::LEFT_SHOULDER)  gp_in.buttons |= gamepad.MAP_BUTTON_LB;
    if (b & XboxOne::GipWireButtons::RIGHT_SHOULDER) gp_in.buttons |= gamepad.MAP_BUTTON_RB;
    if (b & XboxOne::GipWireButtons::BACK)  gp_in.buttons |= gamepad.MAP_BUTTON_BACK;
    if (b & XboxOne::GipWireButtons::START) gp_in.buttons |= gamepad.MAP_BUTTON_START;
    if (b & XboxOne::GipWireButtons::SYNC)  gp_in.buttons |= gamepad.MAP_BUTTON_MISC;
    if (guide_pressed) gp_in.buttons |= gamepad.MAP_BUTTON_SYS;
    if (b & XboxOne::GipWireButtons::A)     gp_in.buttons |= gamepad.MAP_BUTTON_A;
    if (b & XboxOne::GipWireButtons::B)     gp_in.buttons |= gamepad.MAP_BUTTON_B;
    if (b & XboxOne::GipWireButtons::X)     gp_in.buttons |= gamepad.MAP_BUTTON_X;
    if (b & XboxOne::GipWireButtons::Y)     gp_in.buttons |= gamepad.MAP_BUTTON_Y;

    gp_in.trigger_l = gamepad.scale_trigger_l(static_cast<uint8_t>(in_report->trigger_l >> 2));
    gp_in.trigger_r = gamepad.scale_trigger_r(static_cast<uint8_t>(in_report->trigger_r >> 2));

    std::tie(gp_in.joystick_lx, gp_in.joystick_ly) = gamepad.scale_joystick_l(in_report->joystick_lx, in_report->joystick_ly, true);
    std::tie(gp_in.joystick_rx, gp_in.joystick_ry) = gamepad.scale_joystick_r(in_report->joystick_rx, in_report->joystick_ry, true);
}

void XboxOneHost::process_report(Gamepad& gamepad, uint8_t address, uint8_t instance, const uint8_t* report, uint16_t len)
{
    const uint8_t cmd = report[0];
    if (cmd == XboxOne::GIP_CMD_VIRTUAL_KEY)
    {
        last_guide_07_ms_ = board_api::ms_since_boot();
        if (len >= 5) {
            if (report[4] == 0x5B && len >= 6)
                guide_pressed_ = (report[5] & 0x01) ? 1 : 0;
            else
                guide_pressed_ = (report[4] & 0x01) ? 1 : 0;
        }
        Gamepad::PadIn gp_in;
        if (gip_arcade_stick_ && prev_arcade_len_ >= 23)
        {
            XboxArcadeStick::map_gip_arcade_report(prev_arcade_report_.data(), prev_arcade_len_, gamepad, gp_in);
        }
        else
        {
            map_gip_buttons(gamepad, &prev_in_report_, gp_in, guide_pressed_);
        }
        if (guide_pressed_)
        {
            gp_in.buttons |= gamepad.MAP_BUTTON_SYS;
        }
        gamepad.set_pad_in(gp_in);
        tuh_xinput::receive_report(address, instance);
        return;
    }

    if (cmd != XboxOne::GIP_CMD_INPUT)
    {
        tuh_xinput::receive_report(address, instance);
        return;
    }

    if (gip_arcade_stick_)
    {
        bool guide_cleared = false;
        if (guide_pressed_ && (board_api::ms_since_boot() - last_guide_07_ms_) > GUIDE_STALE_MS)
        {
            guide_pressed_ = 0;
            guide_cleared = true;
        }
        if (!guide_cleared &&
            !XboxArcadeStick::gip_arcade_report_changed(report, len, prev_arcade_report_.data(), prev_arcade_len_))
        {
            tuh_xinput::receive_report(address, instance);
            return;
        }

        Gamepad::PadIn gp_in;
        XboxArcadeStick::map_gip_arcade_report(report, len, gamepad, gp_in);
        if (guide_pressed_)
        {
            gp_in.buttons |= gamepad.MAP_BUTTON_SYS;
        }

        gamepad.set_pad_in(gp_in);
        tuh_xinput::receive_report(address, instance);

        const uint16_t copy_len = std::min<uint16_t>(len, static_cast<uint16_t>(prev_arcade_report_.size()));
        std::memcpy(prev_arcade_report_.data(), report, copy_len);
        prev_arcade_len_ = copy_len;
        return;
    }

    if (len < sizeof(XboxOne::InReport))
    {
        tuh_xinput::receive_report(address, instance);
        return;
    }

    const XboxOne::InReport* in_report = reinterpret_cast<const XboxOne::InReport*>(report);
    bool guide_cleared = false;
    if (guide_pressed_ && (board_api::ms_since_boot() - last_guide_07_ms_) > GUIDE_STALE_MS) {
        guide_pressed_ = 0;
        guide_cleared = true;
    }
    if (std::memcmp(&prev_in_report_ + 4, in_report + 4, 14) == 0 && !guide_cleared)
    {
        tuh_xinput::receive_report(address, instance);
        return;
    }

    Gamepad::PadIn gp_in;
    map_gip_buttons(gamepad, in_report, gp_in, guide_pressed_);
    gamepad.set_pad_in(gp_in);

    tuh_xinput::receive_report(address, instance);
    std::memcpy(&prev_in_report_, in_report, sizeof(XboxOne::InReport));
}

bool XboxOneHost::send_feedback(Gamepad& gamepad, uint8_t address, uint8_t instance)
{
    Gamepad::PadOut gp_out = gamepad.get_pad_out();
    return tuh_xinput::set_rumble(address, instance, gp_out.rumble_l, gp_out.rumble_r, false);
}
