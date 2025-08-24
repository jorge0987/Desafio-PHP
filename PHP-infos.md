FPM (FastCGI Process Manager) é uma implementação primária do PHP FastCGI contendo alguns recursos (principalmente) úteis para sites pesados.

Esses recursos incluem:

gerenciamento avançado de processos com parada/início elegante;

pools que dão capacidade de iniciar trabalhadores com diferentes uid/gid/chroot/environment, escutando em diferentes portas e usando php.ini diferente (substitui safe_mode);

registro stdout e stderr configurável;

reinicialização de emergência em caso de destruição acidental do cache de opcode;

suporte acelerado ao upload;

"slowlog" - scripts de registro (não apenas seus nomes, mas seu PHP backtraces também, usando ptrace e coisas semelhantes para ler remotamente process' execute_data) que são executados de forma anormalmente lenta;