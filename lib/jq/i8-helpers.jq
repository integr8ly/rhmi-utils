module {
  "name": "i8-helpers",
  "description": "jq module with helper functions primarily to convert resource values between different units (memory Si vs IEC, cpu cores vs. millicores)",
  "homepage": "https://github.com/integr8ly/rhmi-utils#readme",
  "license": "Apache",
  "author": "Jesse Sarnovsky",
  "version": "1.0.0",
  "jq": "1.5",
  "repository": {
    "type": "git",
    "url": "https://github.com/integr8ly/rhmi-utils.git"
  }
};

def pow(n):
  if n == 0 then 1
  elif . == 0 then 0
  else ( (n | floor) == n) as $intp
       | ( (n % 2) | if . == 0 then 1 else -1 end ) as $sign
       | if . == -1 and $intp then $sign
         elif . < 0 then -(.) | pow(n) * $sign
         elif $intp and n > 0 then . * pow(n - 1)
         else log * n | exp
         end
  end;

def mem_to_bytes(v):
  if (v | type != "string") then v else
    v | capture("(?<n>[0-9]+)(?<u>[A-Z])(?<i>i|)") as $in
    | (if ($in.i=="i") then 1024 else 1000 end) as $mod
    | (("BKMGTPEZY" | index($in.u))) as $power
    | (($mod | pow($power)) * ($in.n | tonumber))
  end;

def cpu_to_mcores($v):
  if (v | type != "string") then v else
    if (v | endswith("m")) then
      v[:-1]|tonumber
    else
      (v|tonumber)*1000
    end
  end;

def normalize_cpu($v):
  if ($v == "0") then 0 else
    if ($v | type != "string") then $v else
      if ($v | endswith("m")) then
        ($v[:-1]|tonumber)/1000
      else
        ($v|tonumber)
      end
    end
  end;

def sum(s): reduce s as $x (null; . + $x );

def roundit: .*100.0 + 0.5|floor/100.0;

#
def xinputs: if . == null then inputs else . end;

def normalizeResources:
  .cpu? = normalize_cpu(.cpu) |
  .memory? = mem_to_bytes(.memory) |
  .storage? = mem_to_bytes(.storage);


def prettyBytes:
  if type=="number" and .>1000 then (
    [while(.>1; ./1000)] | [
      (last*100.0|round|./100.0),
      ("BKMGTPEZY"|split(""))[length]
    ] | join(" "))
  else . end;

def prettyBytes(units):
  if $units == "auto" then
    prettyBytes
  else
    # TODO: add support for units with and w/o i
    error("not yet implemented")
  end;

def leftJoin(a1; a2; field):
  # hash phase:
  (reduce a2[] as $o ({}; . + { ($o | field): $o } )) as $h2
  # join phase:
  | reduce a1[] as $o ([]; . + [$h2[$o | field] + $o ])|.[];

def process:
  [
    .[] |
    {
      "key": .id,
      "value": (.result.items? // .result)
    }
  ] | from_entries;
