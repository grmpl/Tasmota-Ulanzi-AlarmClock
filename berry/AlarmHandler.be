class AlarmHandler
    var beeplist # Defines the beeping sequence
    var beepindex #  controls the current beeping sequence

    def init()
        # beeplist: starting every 3 seconds
        self.beeplist = [1,0,0,1,0,0,1,0,0,1,0,0,1,0,0]
        #  now every 2 seconds
        self.beeplist = self.beeplist + [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1]
        #  increasing
        self.beeplist = self.beeplist + [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
        #  increasing
        self.beeplist = self.beeplist + [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2]
        #  increasing
        self.beeplist = self.beeplist + [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3]
        #  increasing
        self.beeplist = self.beeplist + [4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4]
        self.beepindex = 0
    end

    def beep()
        var buzzerattr

        if self.beepindex < self.beeplist.size()
            buzzerattr = str(self.beeplist[self.beepindex]) +",1"
            tasmota.cmd("buzzer "+buzzerattr, true)
            self.beepindex += 1
        # Alarm off
        else
            self.beepindex = 0
            tasmota.cmd("Mem1 0", true)
            log("AlarmHandler: Timeout Alarm",2)
            # Todo: Message on MQTT and Telegram
        end
    end
end

return AlarmHandler

#-
def beep()
    mah.beep()
    tasmota.set_timer(1000,beep,"beeper")
  end
-#
