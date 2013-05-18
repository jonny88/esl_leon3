------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2012, Aeroflex Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Entity: 	grgprbank
-- File:	grgprbank.vhd
-- Author:	Magnus Hjorth - Aeroflex Gaisler
-- Description:	General purpose register bank
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

entity grgprbank is
  generic (
    pindex: integer := 0;
    paddr : integer := 0;
    pmask : integer := 16#fff#;
    regbits: integer range 1 to 32 := 32;
    nregs : integer  range 1 to 32 := 1;
    rstval: integer := 0
    );
  port (
    rst     : in  std_ulogic;
    clk     : in  std_ulogic;
    apbi    : in  apb_slv_in_type;
    apbo    : out apb_slv_out_type;
    rego    : out std_logic_vector(nregs*regbits-1 downto 0)
    );
end;

architecture rtl of grgprbank is

  constant nregsp2: integer := 2**log2(nregs);
    
  subtype regtype is std_logic_vector(regbits-1 downto 0);
  type regbank is array(nregsp2-1 downto 0) of regtype;

  type grgprbank_regs is record
    regs: regbank;
  end record;

  signal r,nr: grgprbank_regs;

  constant pconfig: apb_config_type := (
    0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_GPREGBANK, 0, 0, 0),
    1 => apb_iobar(paddr, pmask));
  
begin

  comb: process(r,rst,apbi)
    variable v: grgprbank_regs;
    variable o: apb_slv_out_type;
  begin
    -- Init vars
    v := r;
    o := apb_none;
    o.pindex := pindex;
    o.pconfig := pconfig;
    -- APB Interface
    if nregs > 1 then
      o.prdata(regbits-1 downto 0) := r.regs(to_integer(unsigned(apbi.paddr(1+log2(nregs) downto 2))));
      if apbi.penable='1' and apbi.psel(pindex)='1' and apbi.pwrite='1' then
        v.regs(to_integer(unsigned(apbi.paddr(1+log2(nregs) downto 2)))) := apbi.pwdata(regbits-1 downto 0);
      end if;      
    else
      o.prdata(regbits-1 downto 0) := r.regs(0);
      if apbi.penable='1' and apbi.psel(pindex)='1' and apbi.pwrite='1' then
        v.regs(0) := apbi.pwdata(regbits-1 downto 0);
      end if;      
    end if;
    -- Reset
    if rst='0' then
      v.regs := (others => std_logic_vector(to_unsigned(rstval,regbits)));
    end if;
    -- clear unused part of reg bank so it can be pruned
    if nregs < nregsp2 then
      for x in nregsp2-1 downto nregs loop
        v.regs(x) := (others => '0');
      end loop;
    end if;
    -- Drive outputs
    nr <= v;
    apbo <= o;
    for x in nregs-1 downto 0 loop
      rego(x*regbits+regbits-1 downto x*regbits) <= r.regs(x);
    end loop;
  end process;
  
  regs: process(clk)
  begin
    if rising_edge(clk) then r <= nr; end if;
  end process;
  
end;
