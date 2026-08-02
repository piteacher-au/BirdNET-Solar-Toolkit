"""Minimal INA219 driver configured for the Waveshare UPS HAT (B)."""

try:
    import smbus
except ImportError:  # fallback for distributions that do not package smbus
    import smbus2 as smbus


class INA219:
    """Read voltage, current, and power from an INA219 current monitor."""

    REG_CONFIG = 0x00
    REG_SHUNT_VOLTAGE = 0x01
    REG_BUS_VOLTAGE = 0x02
    REG_POWER = 0x03
    REG_CURRENT = 0x04
    REG_CALIBRATION = 0x05

    def __init__(self, bus_number=1, address=0x42):
        self.bus = smbus.SMBus(bus_number)
        self.address = address
        self._calibration = 4096
        self._current_lsb_ma = 0.1
        self._power_lsb_w = 0.002
        self.configure()

    def _read_u16(self, register):
        high, low = self.bus.read_i2c_block_data(self.address, register, 2)
        return (high << 8) | low

    def _read_i16(self, register):
        value = self._read_u16(register)
        return value - 65536 if value >= 32768 else value

    def _write_u16(self, register, value):
        self.bus.write_i2c_block_data(self.address, register, [(value >> 8) & 0xFF, value & 0xFF])

    def configure(self):
        """Configure 32 V, 2 A measurement mode for the HAT's 0.1 ohm shunt."""
        self._write_u16(self.REG_CALIBRATION, self._calibration)
        self._write_u16(self.REG_CONFIG, 0x399F)

    def bus_voltage_v(self):
        return (self._read_u16(self.REG_BUS_VOLTAGE) >> 3) * 0.004

    def current_a(self):
        self._write_u16(self.REG_CALIBRATION, self._calibration)
        return (self._read_i16(self.REG_CURRENT) * self._current_lsb_ma) / 1000

    def power_w(self):
        self._write_u16(self.REG_CALIBRATION, self._calibration)
        return self._read_u16(self.REG_POWER) * self._power_lsb_w
