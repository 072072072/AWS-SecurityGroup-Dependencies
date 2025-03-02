# check-aws-security-group-dependencies-072.sh

Screenshot:
![image](https://github.com/user-attachments/assets/60d5043e-2a45-4f8c-9108-ab6c6e8786a7)


# 스크립트 사용법 출력

본 스크립트는 AWS 환경에서 보안그룹(Security Group)의 사용처를 포괄적으로 확인하는 도구입니다.
보안그룹의 이름이나 id를 입력받아 aws 다양한 리소스에서 해당 보안그룹이 어떻게 사용되고 있는지 확인해드립니다.

문의 : https://www.linkedin.com/in/072072072yc/


# 스크립트 사용법

```bash
사용법: ./check-aws-security-group-dependencies-072.sh [-n 보안그룹-이름] [-i 보안그룹-ID]

옵션:
  -n: 보안그룹 이름 (예: ec2-sbs-web-test)
  -i: 보안그룹 ID (예: sg-xxx)

예시:
  ./check-aws-security-group-dependencies-072.sh -n ec2-sbs-web-test
  ./check-aws-security-group-dependencies-072.sh -i sg-0123456789
  ./check-aws-security-group-dependencies-072.sh -n ec2-sbs-web-test -i sg-0123456789

```


# Find-unused-security-groups.py
..업데이트중입니다.

