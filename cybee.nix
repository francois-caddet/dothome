{ ... }:
{
home.shellAliases = {
tunnelRabbit="ssh -N -L 5672:127.0.0.1:5672 linux@164.30.72.223";
tunnelPostgres="ssh -N -L 5432:127.0.0.1:5432 linux@164.30.72.223";
tunnelTemporal="ssh -N -L 7233:127.0.0.1:7233 linux@164.30.72.223";
sshCybee="ssh linux@164.30.72.223";
};
}
