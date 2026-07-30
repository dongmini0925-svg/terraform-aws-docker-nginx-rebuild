# Terraform AWS Docker CI/CD Infrastructure

Terraform으로 AWS 인프라를 구축하고, GitHub Actions와 Docker Hub를 이용해 Docker 애플리케이션을 Auto Scaling Group에 자동 배포하는 프로젝트입니다.

AWS 장애 감지, 자동 복구, CPU 기반 확장·축소, SNS 이메일 알림, CloudWatch Logs 수집까지 구현했습니다.

---

## 1. 프로젝트 목표

- Terraform을 이용한 AWS 인프라 코드화
- Multi-AZ 기반 고가용성 웹 서비스 구성
- Docker Nginx 애플리케이션 배포
- Application Load Balancer를 통한 트래픽 분산
- Auto Scaling Group을 통한 자동 복구 및 확장
- GitHub Actions 기반 CI/CD 자동화
- GitHub OIDC를 이용한 AWS 임시 권한 획득
- CloudWatch와 SNS를 이용한 장애 알림
- CloudWatch Agent를 이용한 로그 중앙 수집

---

## 2. 전체 아키텍처

```text
Git Push
   |
   v
GitHub Actions
   |
   +--> Docker 이미지 빌드
   |
   +--> Docker Hub 업로드
   |
   +--> GitHub OIDC로 AWS 임시 권한 획득
   |
   +--> Auto Scaling Instance Refresh
                         |
                         v
Internet
   |
   v
Application Load Balancer
   |
   v
Target Group
   |
   +--> EC2 / Docker Nginx / AZ 1
   |
   +--> EC2 / Docker Nginx / AZ 2
             |
             v
      CloudWatch Agent
             |
             v
       CloudWatch Logs
```

---

## 3. 주요 AWS 구성

### 네트워크

- VPC: `10.0.0.0/16`
- Public Subnet 1: `10.0.1.0/24`
- Public Subnet 2: `10.0.2.0/24`
- 서로 다른 가용 영역 사용
- Internet Gateway 연결
- Public Route Table 구성
- ALB 보안 그룹과 EC2 보안 그룹 분리

### Application Load Balancer

- 인터넷에서 HTTP 80번 요청 수신
- Listener가 요청을 Target Group으로 전달
- Target Group Health Check를 통과한 EC2에만 요청 전달
- EC2 한 대에 장애가 발생해도 남은 정상 EC2가 서비스 유지

### Auto Scaling Group

- 최소 용량: 2대
- 희망 용량: 2대
- 최대 용량: 4대
- 두 가용 영역에 EC2 분산 배치
- ELB Health Check를 이용한 비정상 EC2 자동 교체
- 평균 CPU 사용률 20% 기준 Target Tracking Scaling 적용

### Docker

- Ubuntu EC2 생성 시 `user-data.sh` 자동 실행
- Docker 설치 및 서비스 시작
- Docker Hub에서 최신 이미지 다운로드
- Nginx 컨테이너를 80번 포트로 실행

---

## 4. CI/CD 흐름

```text
docker/index.html 수정
→ Git Commit
→ Git Push
→ GitHub Actions 실행
→ Docker 이미지 빌드
→ Docker Hub에 latest 및 Git Commit SHA 태그 업로드
→ GitHub OIDC로 AWS 임시 권한 획득
→ Auto Scaling Group Instance Refresh 시작
→ 새로운 EC2가 최신 Docker 이미지 실행
→ Target Group Health Check 통과
→ 기존 EC2 교체
→ ALB에 새 웹페이지 반영
```

AWS Access Key를 GitHub에 저장하지 않고, GitHub OIDC와 IAM Role을 이용해 임시 권한을 획득하도록 구성했습니다.

---

## 5. 모니터링과 장애 대응

### CloudWatch Alarm

Target Group의 다음 지표를 감시합니다.

```text
Namespace: AWS/ApplicationELB
Metric: UnHealthyHostCount
조건: 비정상 대상이 1대 이상
```

장애 발생 흐름:

```text
Nginx 장애
→ Target Group Unhealthy
→ CloudWatch ALARM
→ SNS 이메일 알림
→ Auto Scaling Group이 비정상 EC2 종료
→ 새 EC2 자동 생성
→ Target Group Healthy
→ CloudWatch OK 복구
→ SNS 복구 알림
```

### CloudWatch Logs

CloudWatch Agent를 통해 다음 로그를 수집합니다.

```text
/aws/ec2/my-asg/user-data
→ EC2 부팅, Docker 설치, 이미지 Pull, Agent 설치 로그

/aws/ec2/my-asg/docker
→ Docker Nginx 컨테이너 실행 및 요청 로그
```

각 EC2 인스턴스 ID를 별도의 로그 스트림 이름으로 사용합니다.

---

## 6. 프로젝트 구조

```text
aws-network-rebuild/
├─ .github/
│  └─ workflows/
│     └─ docker-publish.yml
├─ docker/
│  ├─ Dockerfile
│  └─ index.html
├─ .gitignore
├─ .terraform.lock.hcl
├─ alb.tf
├─ asg.tf
├─ cloudwatch-agent-config.json
├─ iam.tf
├─ main.tf
├─ monitoring.tf
├─ outputs.tf
├─ provider.tf
├─ user-data.sh
└─ README.md
```

### 파일별 역할

| 파일 | 역할 |
|---|---|
| `provider.tf` | Terraform AWS Provider와 리전 설정 |
| `main.tf` | VPC, Subnet, IGW, Route Table, Security Group, AMI 조회 |
| `alb.tf` | ALB, Listener, Target Group 구성 |
| `asg.tf` | Launch Template, Auto Scaling Group, CPU Scaling Policy |
| `iam.tf` | EC2 CloudWatch Agent용 IAM Role과 Instance Profile |
| `monitoring.tf` | CloudWatch Alarm, SNS, Log Group |
| `outputs.tf` | ALB 주소, ASG 이름, Launch Template ID 출력 |
| `user-data.sh` | Docker, Nginx, CloudWatch Agent 자동 설치 |
| `cloudwatch-agent-config.json` | CloudWatch Agent 로그 수집 설정 |
| `docker/` | Nginx Docker 이미지 소스 |
| `docker-publish.yml` | GitHub Actions CI/CD 워크플로 |

---

## 7. 사전 준비

다음 도구가 필요합니다.

```text
Terraform
AWS CLI
Git
Docker Hub 계정
GitHub 저장소
AWS EC2 Key Pair
```

AWS CLI 인증 상태를 확인합니다.

```powershell
aws sts get-caller-identity
```

서울 리전을 사용합니다.

```text
ap-northeast-2
```

Terraform 코드에는 다음 키페어 이름이 설정되어 있습니다.

```text
MyWEB_Key
```

AWS 계정에 같은 이름의 키페어가 존재해야 합니다.

---

## 8. Terraform 실행

알림받을 이메일을 환경 변수로 설정합니다.

```powershell
$env:TF_VAR_alert_email="본인 이메일 주소"
```

Terraform 초기화와 검증:

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

인프라 생성:

```powershell
terraform apply
```

ALB 주소 확인:

```powershell
terraform output -raw alb_url
```

전체 자원 삭제:

```powershell
terraform destroy
```

삭제 확인:

```powershell
terraform state list
```

출력이 없으면 Terraform이 관리하던 자원이 모두 삭제된 상태입니다.

---

## 9. GitHub Actions Secrets

GitHub Repository Secrets에 다음 값을 등록합니다.

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
AWS_ROLE_ARN
```

민감한 값은 YAML 파일이나 Terraform 코드에 직접 작성하지 않습니다.

---

## 10. 주요 실습 결과

- Terraform으로 전체 인프라 생성 및 삭제
- Multi-AZ EC2 배치 확인
- Target Group EC2 Healthy 확인
- ALB를 통한 Docker Nginx 접속
- CPU 부하 발생 후 EC2 2대에서 4대로 Scale-out
- 부하 종료 후 EC2 4대에서 2대로 Scale-in
- Nginx 중지 후 장애 EC2 자동 교체
- 장애 중에도 ALB 서비스 유지
- CloudWatch ALARM 및 SNS 알림 실행
- GitHub Actions 전체 CI/CD 성공
- Instance Refresh를 통한 최신 이미지 자동 배포
- CloudWatch Logs에서 user-data와 Docker 로그 확인

---

## 11. 실습 중 해결한 문제

### Terraform 문법 오류

중괄호 위치와 줄바꿈 문제를 `terraform fmt`, `terraform validate`로 확인했습니다.

### Provider 초기화 오류

새 Terraform 작업 폴더에서 `terraform init`을 먼저 실행해야 했습니다.

### 보안 그룹 참조 오류

VPC 환경에서는 보안 그룹 이름 대신 보안 그룹 ID를 사용했습니다.

```hcl
vpc_security_group_ids = [
  aws_security_group.my_sg.id
]
```

### user-data 실행 오류

Bash 스크립트를 Terraform 코드와 분리하고, 첫 줄의 Shebang이 파일 첫 번째 위치에서 시작하도록 수정했습니다.

```bash
#!/bin/bash
```

### GitHub Actions Docker 로그인 오류

새 GitHub 저장소에 Repository Secret을 별도로 등록해 해결했습니다.

### GitHub OIDC 권한 오류

IAM Role의 신뢰 정책을 새 GitHub 저장소의 OIDC `sub` 값과 일치시켜 해결했습니다.

### 기존 EC2에 새 설정이 반영되지 않는 문제

Launch Template 새 버전 생성 후 Instance Refresh를 실행해 기존 EC2를 교체했습니다.

---

## 12. 보안과 비용 관리

- Terraform State 파일은 Git에 업로드하지 않습니다.
- `.pem` 키 파일은 Git에 업로드하지 않습니다.
- Docker Hub Token은 GitHub Secrets에 저장합니다.
- AWS 장기 Access Key 대신 GitHub OIDC를 사용합니다.
- EC2에는 IAM Role을 연결해 임시 권한을 사용합니다.
- CloudWatch Log Group 보관 기간은 7일로 제한했습니다.
- 실습이 끝난 뒤 반드시 `terraform destroy`를 실행합니다.

---

## 13. 학습 내용

이 프로젝트를 통해 다음 내용을 실습했습니다.

```text
Terraform Infrastructure as Code
AWS VPC Networking
EC2와 Docker
Application Load Balancer
Target Group Health Check
Launch Template
Auto Scaling Group
Target Tracking Scaling
GitHub Actions CI/CD
GitHub OIDC
IAM Role과 Instance Profile
CloudWatch Alarm
SNS Email Notification
CloudWatch Agent
CloudWatch Logs
장애 감지와 자동 복구
```
## Terraform 리팩터링

Terraform 코드의 재사용성과 관리 편의성을 높이기 위해 다음 항목을 개선했습니다.

- AWS 리전 변수화
- VPC 및 서브넷 CIDR 변수화
- 가용 영역 변수화
- 프로젝트 이름 기반 리소스 이름 통일
- EC2 인스턴스 타입과 키페어 변수화
- Auto Scaling Group 용량 변수화
- 민감한 이메일 값을 `terraform.tfvars`로 분리
- `terraform.tfvars`와 Terraform State를 Git에서 제외

## Terraform 환경 분리

동일한 Terraform 코드를 사용하면서 개발 환경과 운영 환경의 변수 및 State를 분리했습니다.

```text
environments/
├─ dev.backend.hcl
├─ prod.backend.hcl
├─ dev.tfvars.example
└─ prod.tfvars.example
```

### 환경별 설정

| 항목 | dev | prod |
|---|---|---|
| 프로젝트 이름 | `docker-nginx-dev` | `docker-nginx-prod` |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| 인스턴스 유형 | `t3.micro` | `t3.small` |
| ASG 최소 용량 | `1` | `2` |
| ASG 희망 용량 | `1` | `2` |
| ASG 최대 용량 | `2` | `4` |
| State 경로 | `environments/dev/terraform.tfstate` | `environments/prod/terraform.tfstate` |

실제 환경 변수 파일에는 알림 이메일 등 사용자별 값이 포함되므로 Git에서 제외하고, 공개 가능한 `.tfvars.example` 파일만 저장소에 포함합니다.

### dev 환경 실행

```powershell
Copy-Item environments\dev.tfvars.example environments\dev.tfvars
terraform init -reconfigure "-backend-config=environments/dev.backend.hcl"
terraform plan "-var-file=environments/dev.tfvars"
```

### prod 환경 실행

```powershell
Copy-Item environments\prod.tfvars.example environments\prod.tfvars
terraform init -reconfigure "-backend-config=environments/prod.backend.hcl"
terraform plan "-var-file=environments/prod.tfvars"
```

환경을 전환할 때는 Backend 설정 파일과 변수 파일을 반드시 같은 환경으로 지정해야 합니다.

```text
dev.backend.hcl  + dev.tfvars
prod.backend.hcl + prod.tfvars
```

현재 프로젝트는 검증 목적으로 `terraform plan`까지만 실행했으며, 실제 AWS 리소스를 생성하는 `terraform apply`는 실행하지 않았습니다.