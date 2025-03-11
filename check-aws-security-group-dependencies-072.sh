#!/bin/bash

# 스크립트 사용법 출력
# 본 스크립트는 AWS 환경에서 보안그룹(Security Group)의 사용처를 포괄적으로 확인하는 도구입니다.
# 보안그룹의 이름이나 id를 입력받아 aws 다양한 리소스에서 해당 보안그룹이 어떻게 사용되고 있는지 확인해드립니다.
# 문의 : https://www.linkedin.com/in/072072072yc/

usage() {
    echo ""
    echo "출처: https://www.linkedin.com/in/072072072yc/"
    echo ""
    echo "사용법: $0 [-n 보안그룹-이름] [-i 보안그룹-ID]"
    echo ""
    echo "옵션:"
    echo "  -n: 보안그룹 이름 (예: ec2-sbs-web-test)"
    echo "  -i: 보안그룹 ID (예: sg-xxx)"
    echo ""
    echo "예시:"
    echo "  $0 -n ec2-sbs-web-test"
    echo "  $0 -i sg-0123456789"
    echo "  $0 -n ec2-sbs-web-test -i sg-0123456789"
    exit 1
}

# 옵션 파싱
SG_NAME=""
SG_ID=""

while getopts "n:i:h" opt; do
    case $opt in
        n) SG_NAME="$OPTARG" ;;
        i) SG_ID="$OPTARG" ;;
        h) usage ;;
        ?) usage ;;
    esac
done

# 최소한 하나의 옵션이 필요
if [ -z "$SG_NAME" ] && [ -z "$SG_ID" ]; then
    echo "오류: 보안그룹 이름(-n) 또는 보안그룹 ID(-i)가 필요합니다."
    usage
fi

# 보안 그룹 ID 확인/조회
if [ -n "$SG_NAME" ] && [ -z "$SG_ID" ]; then
    echo "보안그룹 이름으로 ID 조회 중..."
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)
    
    if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
        echo "오류: '$SG_NAME' 보안그룹을 찾을 수 없습니다."
        exit 1
    fi
elif [ -n "$SG_ID" ]; then
    # 보안그룹 ID 형식 검증
    if [[ ! $SG_ID =~ ^sg- ]]; then
        echo "오류: 잘못된 보안그룹 ID 형식입니다. 'sg-'로 시작해야 합니다."
        exit 1
    fi
    
    # 보안그룹 ID 존재 여부 확인
    SG_EXISTS=$(aws ec2 describe-security-groups \
        --group-ids "$SG_ID" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ "$SG_EXISTS" == "None" ] || [ -z "$SG_EXISTS" ]; then
        echo "오류: '$SG_ID' 보안그룹 ID를 찾을 수 없습니다."
        exit 1
    fi
fi

# 보안그룹 정보 출력
if [ -n "$SG_NAME" ] && [ -n "$SG_ID" ]; then
    echo "보안 그룹 이름: $SG_NAME"
    echo "보안 그룹 ID: $SG_ID"
elif [ -n "$SG_NAME" ]; then
    echo "보안 그룹 이름: $SG_NAME (ID: $SG_ID)"
else
    SG_NAME=$(aws ec2 describe-security-groups \
        --group-ids "$SG_ID" \
        --query 'SecurityGroups[0].GroupName' \
        --output text)
    echo "보안 그룹 이름: $SG_NAME (ID: $SG_ID)"
fi

echo "===== 사용처 확인 시작 ====="

# EC2 인스턴스 확인
echo "1. EC2 인스턴스 확인"
EC2_RESULT=$(aws ec2 describe-instances \
    --filters "Name=instance.group-id,Values=$SG_ID" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -z "$EC2_RESULT" ]; then
    echo "  사용중인 EC2 인스턴스 없음"
else
    echo "$EC2_RESULT"
fi

# RDS 인스턴스 확인
echo "2. RDS 인스턴스 확인"
RDS_RESULT=$(aws rds describe-db-instances \
    --query 'DBInstances[?VpcSecurityGroups[?VpcSecurityGroupId==`'$SG_ID'`]].[DBInstanceIdentifier]' \
    --output text)

if [ -z "$RDS_RESULT" ]; then
    echo "  사용중인 RDS 인스턴스 없음"
else
    echo "$RDS_RESULT"
fi

# ELB 확인 (Classic Load Balancer)
echo "3. Classic Load Balancer 확인"
ELB_RESULT=$(aws elb describe-load-balancers \
    --query 'LoadBalancerDescriptions[?SecurityGroups[?contains(@,`'$SG_ID'`)]].[LoadBalancerName]' \
    --output text)

if [ -z "$ELB_RESULT" ]; then
    echo "  사용중인 Classic Load Balancer 없음"
else
    echo "$ELB_RESULT"
fi

# ALB/NLB 확인 (Application/Network Load Balancer)
echo "4. Application/Network Load Balancer 확인"
ALB_RESULT=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?SecurityGroups[?contains(@,`'$SG_ID'`)]].[LoadBalancerArn,LoadBalancerName]' \
    --output text)

if [ -z "$ALB_RESULT" ]; then
    echo "  사용중인 Application/Network Load Balancer 없음"
else
    echo "$ALB_RESULT"
fi

# ElastiCache 클러스터 확인
echo "5. ElastiCache 클러스터 확인"
CACHE_RESULT=$(aws elasticache describe-cache-clusters \
    --query 'CacheClusters[?SecurityGroups[?SecurityGroupId==`'$SG_ID'`]].[CacheClusterId]' \
    --output text)

if [ -z "$CACHE_RESULT" ]; then
    echo "  사용중인 ElastiCache 클러스터 없음"
else
    echo "$CACHE_RESULT"
fi

# Lambda 함수 (VPC 설정된 경우) 확인
echo "6. Lambda 함수 확인 (VPC 설정된 경우)"
LAMBDA_RESULT=$(aws lambda list-functions \
    --query 'Functions[?VpcConfig.SecurityGroupIds[?contains(@,`'$SG_ID'`)]].[FunctionName]' \
    --output text)

if [ -z "$LAMBDA_RESULT" ]; then
    echo "  사용중인 Lambda 함수 없음"
else
    echo "$LAMBDA_RESULT"
fi

# ECS 서비스 확인
echo "7. ECS 서비스의 EC2 인스턴스 확인"
ECS_RESULT=$(aws ecs list-container-instances \
    --cluster default \
    --query 'containerInstanceArns[]' \
    --output text)

if [ -z "$ECS_RESULT" ]; then
    echo "  사용중인 ECS 서비스 없음"
else
    while read -r instance; do
        aws ecs describe-container-instances \
            --cluster default \
            --container-instances "$instance" \
            --query 'containerInstances[?ec2InstanceId].[ec2InstanceId]' \
            --output text
    done <<< "$ECS_RESULT"
fi

echo "===== 확인 완료 ====="

