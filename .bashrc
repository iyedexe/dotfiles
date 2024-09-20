parse_git_branch() { 
git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'                          
}                                                                                                                                                                                                                                            
export PS1="\[\e[32m\][\[\e[m\]\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[32m\]\h\[\e[m\]:\[\e[36m\]\w\[\e[m\]\[\e[32m\]]\[\e[m\]\[\033[33m\]\$(parse_git_branch)\[\033[00m\] \[\e[32m\]\\$\[\e[m\] "                                        
