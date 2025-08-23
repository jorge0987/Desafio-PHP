# 🚀 POC: PHP + DevOps/SRE - Demonstração Técnica

## 📋 Objetivo
Esta POC demonstra a implementação de uma aplicação **PHP/Laravel** em ambiente **Kubernetes** com práticas modernas de **DevOps/SRE**, abordando os desafios específicos de aplicações síncronas e stateless em infraestrutura cloud-native.

---

## 🎯 Desafios Técnicos Abordados

### 1. **PHP em Ambiente Containerizado**
- [ ] Otimização de Dockerfile multi-stage para PHP-FPM
- [ ] Configuração de PHP-FPM pools para alta performance
- [ ] Implementação de OPcache em ambiente distribuído
- [ ] Gerenciamento de extensões PHP essenciais

### 2. **Kubernetes para Aplicações PHP**
- [ ] Deployment com estratégias de rolling update
- [ ] Horizontal Pod Autoscaler (HPA) configurado para PHP
- [ ] Vertical Pod Autoscaler (VPA) para otimização de recursos
- [ ] ConfigMaps e Secrets para configurações sensíveis
- [ ] Persistent Volumes para storage de sessões/cache
- [ ] Network Policies para segurança

### 3. **Observabilidade e Monitoramento**
- [ ] Métricas PHP-FPM exportadas para Prometheus
- [ ] Dashboards Grafana específicos para PHP
- [ ] Logs estruturados com correlation IDs
- [ ] Health checks customizados para aplicações PHP
- [ ] Alertas baseados em SLIs/SLOs específicos

### 4. **CI/CD e GitOps**
- [ ] Pipeline automatizado com GitHub Actions
- [ ] Build e push de imagens Docker otimizadas
- [ ] Testes automatizados (PHPUnit, PHPCS, PHPStan)
- [ ] Deploy automatizado com ArgoCD
- [ ] Rollback automatizado em caso de falhas

---

## 🏗️ Arquitetura da Solução

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Load Balancer │────│  Nginx Ingress   │────│   PHP-FPM Pods │
│    (AWS ALB)    │    │   Controller     │    │   (Laravel)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │                        │
                       ┌──────────────────┐    ┌─────────────────┐
                       │    Redis Cache   │    │  MySQL Database │
                       │   (Sessions)     │    │   (RDS/Cloud)   │
                       └──────────────────┘    └─────────────────┘
```

---

## 🛠️ Stack Tecnológica

### **Aplicação**
- **PHP 8.2** + **Laravel 10**
- **Nginx** como proxy reverso
- **PHP-FPM** como process manager
- **Redis** para cache e sessões
- **MySQL** como database principal

### **Infraestrutura**
- **Kubernetes** (EKS/GKE/AKS)
- **Docker** + multi-stage builds
- **Terraform** para IaC
- **Helm Charts** para deploy

### **Observabilidade**
- **Prometheus** + **Grafana**
- **Jaeger** para distributed tracing
- **Fluent Bit** para log aggregation
- **Datadog** (opcional)

### **CI/CD**
- **GitHub Actions** para CI
- **ArgoCD** para GitOps
- **Harbor/ECR** para registry

---

## 📊 Métricas e SLIs Implementados

### **Application Metrics**
- [ ] Response time (P50, P95, P99)
- [ ] Request rate (RPS)
- [ ] Error rate (4xx, 5xx)
- [ ] PHP-FPM pool utilization
- [ ] OPcache hit ratio
- [ ] Database connection pool

### **Infrastructure Metrics**
- [ ] Pod CPU/Memory utilization
- [ ] Node resource usage
- [ ] Network latency
- [ ] Storage IOPS
- [ ] Container restart count

### **Business Metrics**
- [ ] User sessions duration
- [ ] Feature usage tracking
- [ ] API endpoint performance
- [ ] Background job queue size

---

## 🔧 Configurações Específicas PHP

### **PHP-FPM Optimization**
```ini
; Pool configuration for Kubernetes
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20
pm.max_requests = 1000

; Health monitoring
ping.path = /ping
pm.status_path = /status
```

### **OPcache Configuration**
```ini
; Optimized for containerized environment
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
opcache.file_update_protection=0
```

---

## 🐳 Docker Strategy

### **Multi-stage Build Benefits**
1. **Redução de tamanho** da imagem final
2. **Separação de dependências** build vs runtime
3. **Otimização de layers** para cache
4. **Security** - apenas binários necessários

### **Health Checks Implementation**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:9000/ping || exit 1
```

---

## ⚡ Performance Optimizations

### **Application Level**
- [ ] Laravel Octane para performance boost
- [ ] Database query optimization
- [ ] Eager loading para N+1 queries
- [ ] Redis para cache de views/routes
- [ ] CDN para assets estáticos

### **Infrastructure Level**
- [ ] Node affinity para database connections
- [ ] Resource requests/limits otimizados
- [ ] Init containers para warm-up
- [ ] Preemptible nodes para cost optimization

---

## 🔒 Security Implementations

### **Runtime Security**
- [ ] Non-root containers
- [ ] Security contexts restritivos
- [ ] Network policies implementadas
- [ ] Secrets management com External Secrets Operator
- [ ] Image scanning automatizado

### **Application Security**
- [ ] OWASP guidelines implementation
- [ ] Input validation e sanitization
- [ ] CSRF protection configurado
- [ ] Rate limiting por IP/user

---

## 🚨 Disaster Recovery & High Availability

### **Backup Strategy**
- [ ] Database backups automatizados
- [ ] Configuration backup para Git
- [ ] Persistent volume snapshots
- [ ] Cross-region replication

### **Recovery Procedures**
- [ ] RTO: < 5 minutos para rolling back
- [ ] RPO: < 1 hora para data loss
- [ ] Automated failover procedures
- [ ] Runbooks documentados

---

## 📈 Scaling Strategies

### **Horizontal Scaling**
```yaml
# HPA configuration for PHP workloads
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-app
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## 🧪 Testing Strategy

### **Automated Testing Pipeline**
- [ ] **Unit Tests** - PHPUnit coverage > 80%
- [ ] **Integration Tests** - Database e API
- [ ] **Load Testing** - K6 para performance
- [ ] **Security Testing** - OWASP ZAP
- [ ] **Infrastructure Testing** - Terratest

### **Quality Gates**
- [ ] Code coverage mínimo 80%
- [ ] Zero vulnerabilidades críticas
- [ ] Performance regression tests
- [ ] Accessibility compliance

---

## 🎛️ Operational Runbooks

### **Common Issues & Solutions**

#### **High PHP-FPM Pool Utilization**
```bash
# Check current pool status
kubectl exec -it <pod> -- curl localhost:9000/status

# Increase pool size if needed
kubectl patch deployment php-app -p '{"spec":{"template":{"spec":{"containers":[{"name":"php-fpm","env":[{"name":"PM_MAX_CHILDREN","value":"100"}]}]}}}}'
```

#### **OPcache Issues**
```bash
# Clear OPcache without restart
kubectl exec -it <pod> -- php -r "opcache_reset();"

# Monitor OPcache statistics
kubectl exec -it <pod> -- php -r "var_dump(opcache_get_status());"
```

---

## 🎯 Demonstração Prática

### **Cenários para Entrevista**
1. **"Como você escalaria esta aplicação PHP?"**
   - Mostrar HPA em ação
   - Demonstrar VPA recommendations
   - Load testing com K6

2. **"E se precisássemos de zero downtime deployment?"**
   - Rolling update strategy
   - Health checks configurados
   - Readiness/liveness probes

3. **"Como resolveria problemas de sessão em múltiplos pods?"**
   - Redis como session store
   - Sticky sessions vs stateless approach
   - Session affinity configuration

4. **"Como monitoraria performance de PHP-FPM?"**
   - Métricas exportadas para Prometheus
   - Dashboards Grafana customizados
   - Alertas baseados em thresholds

---

## 📚 Próximos Passos

- [ ] Implementar todos os componentes listados
- [ ] Documentar troubleshooting procedures
- [ ] Criar video demo da solução
- [ ] Preparar apresentação técnica
- [ ] Testar cenários de falha e recovery

---

## 📞 Perguntas Frequentes

**Q: Por que usar PHP-FPM em vez de mod_php?**
A: PHP-FPM oferece melhor isolamento de processos, configuração granular de pools e métricas detalhadas essenciais para ambientes Kubernetes.

**Q: Como lidar com a natureza stateless do PHP em K8s?**
A: Implementamos external session storage (Redis), cache distribuído e configuramos aplicação para ser 12-factor compliant.

**Q: Qual a estratégia de resource allocation para PHP?**
A: Baseamos requests/limits em profiling real da aplicação, considerando PHP-FPM pool size e memory_limit configurados.

---

*Esta POC demonstra expertise técnica em DevOps/SRE específica para aplicações PHP, abordando desafios reais de produção e implementando best practices da indústria.*
