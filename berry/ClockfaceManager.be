import fonts
import json
import math
import introspect
import persist

import MatrixController
import AlarmHandler

import ClockClockFace
import DateClockFace
import Alarm1ClockFace
import Alarm2ClockFace
import Alarm3ClockFace
import Alarm4ClockFace



var clockFaces = [
    ClockClockFace,
    DateClockFace,
    Alarm1ClockFace,
    Alarm2ClockFace,
    Alarm3ClockFace,
    Alarm4ClockFace
];

class ClockfaceManager
    var matrixController
    var alarmHandler
    var brightness
    var color
    var currentClockFace
    var currentClockFaceIdx
    var snoozerunning

    static snoozetime=300 # 5 minutes


    def init()
        log("ClockfaceManager Init",3);
        self.matrixController = MatrixController()
        self.alarmHandler = AlarmHandler()

        self.brightness = 50;
        self.color = fonts.palette['red']

        self.matrixController.print_string("Hello :)", 3, 2, true, self.color, self.brightness)
        self.matrixController.draw()

        self.currentClockFaceIdx = 0
        self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

        tasmota.add_rule("Button1#State", / value, trigger, msg -> self.on_button_prev(value, trigger, msg))
        tasmota.add_rule("Button2#State", / value, trigger, msg -> self.on_button_action(value, trigger, msg))
        tasmota.add_rule("Button3#State", / value, trigger, msg -> self.on_button_next(value, trigger, msg))

        # Reset Snooze after reinit
        self.snoozerunning = 0
        persist.snooze = 0

         
    end

    def on_button_prev(value, trigger, msg)
        # print(value)
        # print(trigger)
        # print(msg)
        # If Alarm is active and no Snooze, activate Snooze, do nothing
        if int(tasmota.cmd("_Mem1",true)['Mem1']) > 0 && persist.member('snooze') == 0
            log("Snooze activated by button_prev",2)
            tasmota.cmd("_buzzer 0",true)
            persist.snooze=1
            persist.save()
            self.snoozerunning = self.snoozetime
            # I suspect interference with other redraws, so this is disabled.
            # self.redraw()
        else

            self.currentClockFaceIdx = (self.currentClockFaceIdx + (size(clockFaces) - 1)) % size(clockFaces)
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

            #self.redraw()
        end
    end

    def on_button_action(value, trigger, msg)
               
        # If Alarm is active handle button different
        var alarmset = int(tasmota.cmd("_Mem1",true)['Mem1'])
        if alarmset > 0 && value == 3 #Hold - switch off Alarm
            log("ClockfaceManager: Alarm switched off",2)
            tasmota.cmd("_buzzer 1",true)
            tasmota.cmd("_Mem1 0",true)
            #self.redraw()
        elif  alarmset > 0 && persist.member('snooze') == 0 #else Snooze on
            log("ClockfaceManager: Snooze activated by button_action",2)
            tasmota.cmd("_buzzer 0",true)
            persist.snooze=1
            persist.save()
            self.snoozerunning = self.snoozetime
            #self.redraw()
        else
            var handleActionMethod = introspect.get(self.currentClockFace, "handleActionButton");
            if handleActionMethod != nil
                self.currentClockFace.handleActionButton()
            end
        end
    end

    def on_button_next(value, trigger, msg)
        # print(value)
        # print(trigger)
        # print(msg)
        # If Alarm is active and no Snooze, activate Snooze
        if int(tasmota.cmd("_Mem1",true)['Mem1']) > 0 && persist.member('snooze') == 0
            log("ClockfaceManager: Snooze activated by button_next",2)
            tasmota.cmd("_buzzer 0",true)
            persist.snooze=1
            persist.save()
            self.snoozerunning = self.snoozetime
            self.redraw()
        else
            self.currentClockFaceIdx = (self.currentClockFaceIdx + 1) % size(clockFaces)
            self.currentClockFace = clockFaces[self.currentClockFaceIdx](self)

            self.redraw()
        end
    end


    # This will be called automatically every 1s by the tasmota framework
    def every_second()


        # Check for Alarm
        var alarmset = int(tasmota.cmd("_Mem1",true)['Mem1'])
        # Alarm set and no Snooze
        if alarmset > 0 && persist.member('snooze') == 0
            log("ClockfaceManager: Alarm active, beeping",3)
            self.alarmHandler.beep()
        # Alarm set and Snooze on
        elif alarmset > 0 && persist.member('snooze') > 0
            # Snooze decrement
            if self.snoozerunning > 1
                log("ClockfaceManager: Snooze active, decrementing",3)
                self.snoozerunning = self.snoozerunning - 1
            # Snooze at 1 or 0
            else
                log("ClockfaceManager: End of Snooze",3)
                persist.snooze = 0
                persist.save()
                self.snoozerunning = 0
                self.alarmHandler.beepindex = 0
                self.alarmHandler.beep()
            end
        # Alarm off, but still Snooze active
        elif alarmset == 0 && persist.member('snooze') > 0
            log("ClockfaceManager: Alarm off, but Snooze still on",3)
            persist.snooze = 0
            self.snoozerunning = 0
            persist.save()
        end

        self.update_brightness_from_sensor()
        self.redraw()


    end

    def redraw()
        #var start = tasmota.millis()

        self.currentClockFace.render()
        self.matrixController.draw()

        #print("Redraw took", tasmota.millis() - start, "ms")
    end

    def update_brightness_from_sensor()
        var sensors = json.load(tasmota.read_sensors());
        var illuminance = sensors['ANALOG']['Illuminance1'];

        var brightness = int(10 * math.log(illuminance));
        if brightness < 10
            brightness = 10;
        end
        if brightness > 90
            brightness = 90;
        end
        # print("Brightness: ", self.brightness, ", Illuminance: ", illuminance);

        self.brightness = brightness;
    end

    def save_before_restart()
        # This function may be called on other occasions than just before a restart
        # => We need to make sure that it is in fact a restart
        if tasmota.global.restart_flag == 1 || tasmota.global.restart_flag == 2
            self.currentClockFace = nil;
            self.matrixController.change_font('MatrixDisplay3x5');
            self.matrixController.clear();

            self.matrixController.print_string("Reboot...", 0, 2, true, self.color, self.brightness)
            self.matrixController.draw();
            print("This is just to add some delay");
            print("   ")
            print("According to all known laws of aviation, there is no way a bee should be able to fly.")
            print("Its wings are too small to get its fat little body off the ground.")
            print("The bee, of course, flies anyway, because bees don't care what humans think is impossible")
        end
    end
end

return ClockfaceManager
