FROM nginx:1.25-alpine

copy index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g". "daemon off;"]
